-- FruitStoreSystem.lua - Fruit Store functionality for Build A Zoo
-- Author: Zebux
-- Version: 1.0

local FruitStoreSystem = {}

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Fruit Store Functions
function FruitStoreSystem.getFoodStoreUI()
    local player = Players.LocalPlayer
    if not player then return nil end
    
    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then return nil end
    
    return playerGui:FindFirstChild("ScreenFoodStore")
end

function FruitStoreSystem.getFoodStoreLST()
    local foodStoreUI = FruitStoreSystem.getFoodStoreUI()
    if not foodStoreUI then return nil end
    
    return foodStoreUI:FindFirstChild("LST")
end

function FruitStoreSystem.candidateKeysForFruit(fruitId)
    local candidates = {}
    
    -- Try different possible key formats
    table.insert(candidates, fruitId)
    table.insert(candidates, string.lower(fruitId))
    table.insert(candidates, string.upper(fruitId))
    
    -- Try with spaces replaced by underscores
    local underscoreVersion = fruitId:gsub(" ", "_")
    table.insert(candidates, underscoreVersion)
    table.insert(candidates, string.lower(underscoreVersion))
    
    return candidates
end

function FruitStoreSystem.readStockFromLST(lst, fruitId)
    if not lst then return 0 end
    
    local candidates = FruitStoreSystem.candidateKeysForFruit(fruitId)
    
    for _, candidate in ipairs(candidates) do
        local stockLabel = lst:FindFirstChild(candidate)
        if stockLabel and stockLabel:IsA("TextLabel") then
            local stockText = stockLabel.Text
            local stockNumber = tonumber(stockText:match("%d+"))
            if stockNumber then
                return stockNumber
            end
        end
    end
    
    return 0
end

function FruitStoreSystem.isFruitInStock(fruitId)
    local lst = FruitStoreSystem.getFoodStoreLST()
    if not lst then return false end
    
    local stock = FruitStoreSystem.readStockFromLST(lst, fruitId)
    return stock > 0
end

function FruitStoreSystem.getPlayerNetWorth()
    local player = Players.LocalPlayer
    if not player then return 0 end
    
    local leaderstats = player:FindFirstChild("leaderstats")
    if not leaderstats then return 0 end
    
    local netWorth = leaderstats:FindFirstChild("NetWorth")
    if not netWorth then return 0 end
    
    return netWorth.Value or 0
end

function FruitStoreSystem.parsePrice(priceStr)
    if type(priceStr) == "number" then
        return priceStr
    end
    local cleanPrice = priceStr:gsub(",", "")
    return tonumber(cleanPrice) or 0
end

return FruitStoreSystem
