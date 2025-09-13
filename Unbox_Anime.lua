-- Auto Mining Script using WindUI
-- This script helps you mine automatically like a helpful robot friend!

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

-- Get important game services (like helpers in a game)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- Get the player (that's you!)
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- Variables to control our mining robot
local autoMining = false
local miningConnection = nil
local userPlot = nil
local currentTarget = nil
local serverChestMode = false
local serverChestConnection = nil
local currentServerChest = nil
local autoCollectMoney = false
local moneyCollectionConnection = nil
local autoUpgrade = false
local upgradeConnection = nil
local autoRebirth = false
local rebirthConnection = nil
local autoClaimChest = false
local claimChestConnection = nil
local autoBuyChest = false
local buyChestConnection = nil
local selectedChestTypes = {"Wooden"}
local autoSell = false
local sellConnection = nil
local selectedCharactersToSell = {}
local sellGoldVariant = "Both" -- "Gold", "NonGold", "Both"

-- Tracking variables to prevent spam
local lastToolLevel = -1
local lastLuckLevel = -1
local lastRebirthLevel = -1
local upgradeInProgress = false
local rebirthInProgress = false

-- Cached upgrade data (loaded from ModuleScript)
local upgradeData = nil
local upgradeDataCached = false

-- Cached rebirth data (loaded from ModuleScript)
local rebirthData = nil
local rebirthDataCached = false

-- Cached chest data (hardcoded from provided structure)
local chestData = {
    Bubblegum = {
        Rarity = "Ancient", 
        DisplayName = "Bubblegum Chest", 
        Chance = 0, 
        Health = 25, 
        Price = 1e999, 
        Product = 0, 
        ImageID = "rbxassetid://137442471446876",
        Ignore = true
    },
    Wooden = {
        Rarity = "Common", 
        DisplayName = "Wooden Chest", 
        Chance = 65, 
        Health = 5, 
        Price = 100, 
        Product = 3357896269, 
        ImageID = "rbxassetid://95076693196867"
    },
    Bronze = {
        Rarity = "Uncommon", 
        DisplayName = "Bronze Chest", 
        Chance = 20, 
        Health = 15, 
        Price = 350, 
        Product = 3357895889, 
        ImageID = "rbxassetid://90058854957122"
    },
    Steel = {
        Rarity = "Rare", 
        DisplayName = "Steel Chest", 
        Chance = 8, 
        Health = 25, 
        Price = 1000, 
        Product = 3358892590, 
        ImageID = "rbxassetid://105511869067201"
    },
    Crystal = {
        Rarity = "Epic", 
        DisplayName = "Crystal Chest", 
        Chance = 4, 
        Health = 45, 
        Price = 3000, 
        Product = 3358892701, 
        ImageID = "rbxassetid://72687390747151"
    },
    Shard = {
        Rarity = "Legendary", 
        DisplayName = "Shard Chest", 
        Chance = 1.8, 
        Health = 80, 
        Price = 20000, 
        Product = 3358892778, 
        ImageID = "rbxassetid://140464074574804"
    },
    Flame = {
        Rarity = "Mythic", 
        DisplayName = "Flame Chest", 
        Chance = 0.8, 
        Health = 125, 
        Price = 75000, 
        Product = 3358892902, 
        ImageID = "rbxassetid://106291813739124"
    },
    Mythic = {
        Rarity = "Mythic", 
        DisplayName = "Mythic Chest", 
        Chance = 0.35, 
        Health = 200, 
        Price = 300000, 
        Product = 3358893017, 
        ImageID = "rbxassetid://90625118407134"
    },
    Godly = {
        Rarity = "Godly", 
        DisplayName = "Godly Chest", 
        Chance = 0.03, 
        Health = 425, 
        Price = 1000000, 
        Product = 3358893132, 
        ImageID = "rbxassetid://131310441833686"
    },
    Ruby = {
        Rarity = "Godly", 
        DisplayName = "Ruby Chest", 
        Chance = 0.015, 
        Health = 845, 
        Price = 4500000, 
        Product = 3361398267, 
        ImageID = "rbxassetid://119534777061737"
    },
    Emerald = {
        Rarity = "Ancient", 
        DisplayName = "Emerald Chest", 
        Chance = 0.005, 
        Health = 1150, 
        Price = 10000000, 
        Product = 3361398192, 
        ImageID = "rbxassetid://74433841226383"
    }
}

-- Character data for auto sell system
local characterData = {
    Yagami = {
        DisplayName = "Yagumi", 
        Rarity = "Common", 
        ValuePerSecond = 1, 
        SellValue = 150, 
        RegularImage = "rbxassetid://88721917539440", 
        Animation = "http://www.roblox.com/asset/?id=77881451926239"
    }, 
    Tanjiro = {
        DisplayName = "Tanjiru", 
        Rarity = "Common", 
        ValuePerSecond = 3, 
        SellValue = 450, 
        RegularImage = "rbxassetid://105198235890846", 
        Animation = "http://www.roblox.com/asset/?id=88259710834327"
    }, 
    Bakugo = {
        DisplayName = "Bakuzo", 
        Rarity = "Uncommon", 
        ValuePerSecond = 5, 
        SellValue = 750, 
        RegularImage = "rbxassetid://124718079397356", 
        Animation = "http://www.roblox.com/asset/?id=72969770284231"
    }, 
    Killua = {
        DisplayName = "Kilua", 
        Rarity = "Uncommon", 
        ValuePerSecond = 10, 
        SellValue = 1500, 
        RegularImage = "rbxassetid://131019770088579", 
        Animation = "http://www.roblox.com/asset/?id=135737542991704"
    }, 
    Levi = {
        DisplayName = "Levio", 
        Rarity = "Rare", 
        ValuePerSecond = 12, 
        SellValue = 2250, 
        RegularImage = "rbxassetid://121349193357664", 
        Animation = "http://www.roblox.com/asset/?id=129301053972473"
    }, 
    Zoro = {
        DisplayName = "Zoroa", 
        Rarity = "Rare", 
        ValuePerSecond = 15, 
        SellValue = 3000, 
        RegularImage = "rbxassetid://137528435939086", 
        Animation = "http://www.roblox.com/asset/?id=92297900968198"
    }, 
    Eren = {
        DisplayName = "Eron", 
        Rarity = "Epic", 
        ValuePerSecond = 22, 
        SellValue = 4500, 
        RegularImage = "rbxassetid://95667438242360", 
        Animation = "http://www.roblox.com/asset/?id=81303097209619"
    }, 
    Sasuke = {
        DisplayName = "Saske", 
        Rarity = "Epic", 
        ValuePerSecond = 35, 
        SellValue = 6000, 
        RegularImage = "rbxassetid://127478498238178", 
        Animation = "http://www.roblox.com/asset/?id=113874687169795"
    }, 
    Naruto = {
        DisplayName = "Narito", 
        Rarity = "Legendary", 
        ValuePerSecond = 45, 
        SellValue = 7500, 
        RegularImage = "rbxassetid://90966019317627", 
        Animation = "http://www.roblox.com/asset/?id=10714389396"
    }, 
    Luffy = {
        DisplayName = "Lufi", 
        Rarity = "Legendary", 
        ValuePerSecond = 70, 
        SellValue = 11250, 
        RegularImage = "rbxassetid://74572820911531", 
        Animation = "http://www.roblox.com/asset/?id=113640022576255"
    }, 
    Ichigo = {
        DisplayName = "Ichiga", 
        Rarity = "Mythic", 
        ValuePerSecond = 100, 
        SellValue = 15000, 
        RegularImage = "rbxassetid://121897497623505", 
        Animation = "http://www.roblox.com/asset/?id=98757529243336"
    }, 
    Gojo = {
        DisplayName = "Goju", 
        Rarity = "Godly", 
        ValuePerSecond = 250, 
        SellValue = 37500, 
        RegularImage = "rbxassetid://118872314803857", 
        Animation = "http://www.roblox.com/asset/?id=139942161402086"
    }, 
    Goku = {
        DisplayName = "Gokai", 
        Rarity = "Godly", 
        ValuePerSecond = 500, 
        SellValue = 75000, 
        RegularImage = "rbxassetid://116512426688303", 
        Animation = "http://www.roblox.com/asset/?id=139942161402086"
    }, 
    Denji = {
        DisplayName = "Denzi", 
        Rarity = "Godly", 
        ValuePerSecond = 520, 
        SellValue = 78000, 
        RegularImage = "rbxassetid://102006243939523", 
        Animation = "http://www.roblox.com/asset/?id=109521674573471"
    }, 
    Power = {
        DisplayName = "Powa", 
        Rarity = "Godly", 
        ValuePerSecond = 600, 
        SellValue = 90000, 
        RegularImage = "rbxassetid://80447431950652", 
        Animation = "http://www.roblox.com/asset/?id=111408216669812"
    }, 
    Shanks = {
        DisplayName = "Shankz", 
        Rarity = "Godly", 
        ValuePerSecond = 700, 
        SellValue = 105000, 
        RegularImage = "rbxassetid://121173640174589", 
        Animation = "http://www.roblox.com/asset/?id=85318871059198"
    }, 
    Sukuna = {
        DisplayName = "Sukino", 
        Rarity = "Godly", 
        ValuePerSecond = 800, 
        SellValue = 120000, 
        RegularImage = "rbxassetid://116020967050890", 
        Animation = "http://www.roblox.com/asset/?id=138570970656842"
    }, 
    Trunks = {
        DisplayName = "Tronks", 
        Rarity = "Ancient", 
        ValuePerSecond = 950, 
        SellValue = 142500, 
        RegularImage = "rbxassetid://113098737812307", 
        Animation = "http://www.roblox.com/asset/?id=127626847227920"
    }, 
    Gon = {
        DisplayName = "Gonn", 
        Rarity = "Ancient", 
        ValuePerSecond = 1050, 
        SellValue = 162500, 
        RegularImage = "rbxassetid://82256118870362", 
        Animation = "http://www.roblox.com/asset/?id=127626847227920"
    }, 
    Hisoka = {
        DisplayName = "Hizoka", 
        Rarity = "Ancient", 
        ValuePerSecond = 1350, 
        SellValue = 182500, 
        RegularImage = "rbxassetid://70724296944568", 
        Animation = "http://www.roblox.com/asset/?id=127626847227920"
    }, 
    Leorio = {
        DisplayName = "Leorik", 
        Rarity = "Ancient", 
        ValuePerSecond = 1600, 
        SellValue = 222500, 
        RegularImage = "rbxassetid://133309730193227", 
        Animation = "http://www.roblox.com/asset/?id=127626847227920"
    }, 
    Zoey = {
        DisplayName = "Zoie", 
        Rarity = "K-Pop", 
        ValuePerSecond = 1850, 
        SellValue = 252500, 
        RegularImage = "rbxassetid://81232636811111", 
        Animation = "http://www.roblox.com/asset/?id=127626847227920"
    }, 
    Rumi = {
        DisplayName = "Runi", 
        Rarity = "K-Pop", 
        ValuePerSecond = 2150, 
        SellValue = 312500, 
        RegularImage = "rbxassetid://95920860703903", 
        Animation = "http://www.roblox.com/asset/?id=127626847227920"
    }
}

-- Function to load upgrade data from ModuleScript and cache it
local function loadUpgradeData()
    if upgradeDataCached and upgradeData then
        return upgradeData -- Return cached data
    end
    
    local success, data = pcall(function()
        local replicatedStorage = game:GetService("ReplicatedStorage")
        local config = replicatedStorage:WaitForChild("Config")
        local upgradesModule = config:WaitForChild("Upgrades")
        return require(upgradesModule)
    end)
    
    if success and data then
        upgradeData = data
        upgradeDataCached = true
        
        return upgradeData
    else
        -- Fallback to hardcoded data if ModuleScript fails
        upgradeData = {
            Tool = {
                ProductId = 3357945412, 
                Levels = {
                    [0] = {1, 0}, [1] = {2, 1000}, [2] = {4, 15000}, [3] = {8, 150000}, 
                    [4] = {16, 650000}, [5] = {32, 2500000}, [6] = {40, 15000000}, 
                    [7] = {50, 60000000}, [8] = {65, 250000000}, [9] = {80, 1000000000}, 
                    [10] = {100, 4000000000}
                }
            }, 
            Luck = {
                ProductId = 3357945489, 
                Levels = {
                    [0] = {1, 0}, [1] = {1.1, 5000}, [2] = {1.25, 35000}, [3] = {1.5, 175000}, 
                    [4] = {1.75, 950000}, [5] = {2, 3500000}, [6] = {2.1, 15000000}, 
                    [7] = {2.2, 60000000}, [8] = {2.3, 250000000}, [9] = {2.4, 1000000000}, 
                    [10] = {2.5, 4000000000}
                }
            }
        }
        upgradeDataCached = true
        return upgradeData
    end
end

-- Function to refresh upgrade data cache (useful if game updates)
local function refreshUpgradeData()
    upgradeDataCached = false
    upgradeData = nil
    return loadUpgradeData()
end

-- Function to load rebirth data from ModuleScript and cache it
local function loadRebirthData()
    if rebirthDataCached and rebirthData then
        return rebirthData -- Return cached data
    end
    
    local success, data = pcall(function()
        local replicatedStorage = game:GetService("ReplicatedStorage")
        local config = replicatedStorage:WaitForChild("Config")
        local rebirthsModule = config:WaitForChild("Rebirths")
        return require(rebirthsModule)
    end)
    
    if success and data then
        rebirthData = data
        rebirthDataCached = true
        return rebirthData
    else
        -- Fallback to empty data if ModuleScript fails
        rebirthData = {}
        rebirthDataCached = true
        return rebirthData
    end
end

-- Function to refresh rebirth data cache
local function refreshRebirthData()
    rebirthDataCached = false
    rebirthData = nil
    return loadRebirthData()
end

-- Function to create a beautiful gradient text (makes text colorful!)
function gradient(text, startColor, endColor)
    local result = ""
    local length = #text
    
    for i = 1, length do
        local t = (i - 1) / math.max(length - 1, 1)
        local r = math.floor((startColor.R + (endColor.R - startColor.R) * t) * 255)
        local g = math.floor((startColor.G + (endColor.G - startColor.G) * t) * 255)
        local b = math.floor((startColor.B + (endColor.B - startColor.B) * t) * 255)
        
        local char = text:sub(i, i)
        result = result .. "<font color=\"rgb(" .. r ..", " .. g .. ", " .. b .. ")\">" .. char .. "</font>"
    end
    
    return result
end

-- Function to check if player has pickaxe equipped
local function hasPickaxeEquipped()
    if not character then return false end
    
    local tool = character:FindFirstChildOfClass("Tool")
    if tool and (tool.Name:lower():find("pickaxe") or tool.Name:lower():find("pick")) then
        return true
    end
    
    return false
end

-- Function to find pickaxe in various locations
local function findPickaxe()
    local pickaxe = nil
    
    -- First check backpack
    local backpack = player:WaitForChild("Backpack")
    pickaxe = backpack:FindFirstChild("Pickaxe") or backpack:FindFirstChild("pickaxe")
    if pickaxe then
        return pickaxe, "backpack"
    end
    
    -- Check workspace.user as requested
    local userFolder = workspace:FindFirstChild("user")
    if userFolder then
        -- Look for pickaxe in user folder
        pickaxe = userFolder:FindFirstChild("Pickaxe") or userFolder:FindFirstChild("pickaxe")
        if pickaxe then
            return pickaxe, "workspace_user"
        end
        
        -- Check deeper in user folder structure
        for _, child in pairs(userFolder:GetChildren()) do
            if child:IsA("Model") or child:IsA("Folder") then
                local foundPickaxe = child:FindFirstChild("Pickaxe") or child:FindFirstChild("pickaxe")
                if foundPickaxe then
                    return foundPickaxe, "workspace_user_child"
                end
            end
        end
    end
    
    -- Check character (already equipped)
    if character then
        pickaxe = character:FindFirstChild("Pickaxe") or character:FindFirstChild("pickaxe")
        if pickaxe then
            return pickaxe, "equipped"
        end
    end
    
    -- Check other common locations
    local starterPack = player:FindFirstChild("StarterPack")
    if starterPack then
        pickaxe = starterPack:FindFirstChild("Pickaxe") or starterPack:FindFirstChild("pickaxe")
        if pickaxe then
            return pickaxe, "starterpack"
        end
    end
    
    return nil, "not_found"
end

-- Function to equip pickaxe (like getting your mining tool ready!)
local function equipPickaxe()
    -- First check if already equipped
    if hasPickaxeEquipped() then
        return true
    end
    
    local pickaxe, location = findPickaxe()
    
    if pickaxe then
        if location == "backpack" then
            humanoid:EquipTool(pickaxe)
            return true
        elseif location == "workspace_user" or location == "workspace_user_child" then
            -- Try to move to backpack first, then equip
            pickaxe.Parent = player.Backpack
            wait(0.1)
            humanoid:EquipTool(pickaxe)
            return true
        elseif location == "equipped" then
            return true
        elseif location == "starterpack" then
            -- Clone from StarterPack to Backpack
            local clonedPickaxe = pickaxe:Clone()
            clonedPickaxe.Parent = player.Backpack
            wait(0.1)
            humanoid:EquipTool(clonedPickaxe)
            return true
        end
    else
        return false
    end
end

-- Function to ensure pickaxe is equipped (checks every mining cycle)
local function ensurePickaxeEquipped()
    if not hasPickaxeEquipped() then
        return equipPickaxe()
    end
    return true
end

-- Function to find the user's plot (like finding your own garden!)
local function findUserPlot()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then
        return nil
    end
    
    -- Look through all plots to find yours
    for _, plot in pairs(plots:GetChildren()) do
        if plot:IsA("Model") then
            local owner = plot:GetAttribute("Owner")
            if owner and owner == player.Name then
                return plot
            end
        end
    end
    
    return nil
end

-- Function to find chests with health > 0 (like finding treasure boxes to open!)
local function findValidChest(plot)
    if not plot then return nil end
    
    local chests = plot:FindFirstChild("Chests")
    if not chests then
        return nil
    end
    
    -- Look for chests with health
    for _, chest in pairs(chests:GetChildren()) do
        if chest:IsA("Model") then
            local health = chest:GetAttribute("Health")
            if health and health > 0 then
                return chest
            end
        end
    end
    
    return nil
end

-- Function to teleport to a chest (like magic transportation!)
local function teleportToChest(chest)
    if not chest or not chest.PrimaryPart then
        -- Try to find a part to teleport to
        local targetPart = chest:FindFirstChildOfClass("Part")
        if not targetPart then return false end
        
        local targetPosition = targetPart.Position + Vector3.new(0, 5, 0)
        humanoidRootPart.CFrame = CFrame.new(targetPosition)
        return true
    else
        local targetPosition = chest.PrimaryPart.Position + Vector3.new(0, 5, 0)
        humanoidRootPart.CFrame = CFrame.new(targetPosition)
        return true
    end
end

-- Function to fire the hammer (like using your mining power!)
local function fireHammer()
    local remotes = ReplicatedStorage:WaitForChild("Remotes")
    local hammerRemote = remotes:WaitForChild("HammerActivated")
    
    hammerRemote:FireServer()
end

-- Function to check for ServerChest (like looking for special treasure!)
local function findServerChest()
    -- Use GetDescendants to search for ServerChest
    for _, descendant in pairs(workspace:GetDescendants()) do
        if descendant.Name == "ServerChest" and descendant.Parent and descendant.Parent.Name == "ServerChest" then
            -- Found workspace.ServerChest.ServerChest
            return descendant
        end
    end
    return nil
end

-- Function to monitor ServerChest appearance/disappearance
local function startServerChestMonitoring()
    if serverChestConnection then
        serverChestConnection:Disconnect()
    end
    
    serverChestConnection = RunService.Heartbeat:Connect(function()
        if not serverChestMode then return end
        
        local serverChest = findServerChest()
        
        if serverChest and not currentServerChest then
            -- ServerChest appeared!
            currentServerChest = serverChest
            
            -- Teleport to ServerChest
            if serverChest.PrimaryPart then
                local targetPosition = serverChest.PrimaryPart.Position + Vector3.new(0, 5, 0)
                humanoidRootPart.CFrame = CFrame.new(targetPosition)
            else
                -- Try to find a part to teleport to
                local targetPart = serverChest:FindFirstChildOfClass("Part")
                if targetPart then
                    local targetPosition = targetPart.Position + Vector3.new(0, 5, 0)
                    humanoidRootPart.CFrame = CFrame.new(targetPosition)
                end
            end
            
                WindUI:Notify({
                    Title = "ServerChest Found",
                    Content = "Teleported to ServerChest",
                    Duration = 3,
                    Icon = "star"
                })
            
        elseif not serverChest and currentServerChest then
            -- ServerChest disappeared!
            currentServerChest = nil
            
            -- Find a chest in the user's plot to return to
            if userPlot then
                local chest = findValidChest(userPlot)
                if chest then
                    teleportToChest(chest)
                    currentTarget = chest
                end
            end
            
            WindUI:Notify({
                Title = "ServerChest Gone",
                Content = "Returned to plot mining",
                Duration = 3,
                Icon = "arrow-left"
            })
        end
    end)
end

-- Function to stop ServerChest monitoring
local function stopServerChestMonitoring()
    if serverChestConnection then
        serverChestConnection:Disconnect()
        serverChestConnection = nil
    end
    currentServerChest = nil
end

-- Function to process a single pad for money collection
local function processPad(padNumber, plot)
    if not plot then return false end
    
    local padsFolder = plot:FindFirstChild("Pads")
    if not padsFolder then return false end
    
    local pad = padsFolder:FindFirstChild(tostring(padNumber))
    if not pad then return false end
    
    local collectFolder = pad:FindFirstChild("Collect")
    if not collectFolder then return false end
    
    local button = collectFolder:FindFirstChild("Button")
    if not button then return false end
    
    -- Check current size
    local currentSize = button.Size
    local targetSize = Vector3.new(1000, 2, 1000)
    
    -- If size is not the target size, change it
    if currentSize ~= targetSize then
        button.Size = targetSize
    end
    
    -- Set transparency to 1 (invisible)
    if button.Transparency ~= 1 then
        button.Transparency = 1
    end
    
    return true
end

-- Function to collect money from all pads (like a money magnet!)
local function collectMoneyFromPads()
    if not userPlot then
        userPlot = findUserPlot()
        if not userPlot then return end
    end
    
    local processedPads = 0
    
    -- Check pads 1 through 14
    for i = 1, 14 do
        if processPad(i, userPlot) then
            processedPads = processedPads + 1
        end
    end
    
end

-- Function to start auto money collection
local function startMoneyCollection()
    if moneyCollectionConnection then
        moneyCollectionConnection:Disconnect()
    end
    
    moneyCollectionConnection = RunService.Heartbeat:Connect(function()
        if not autoCollectMoney then return end
        
        -- Update character reference if respawned
        character = player.Character
        if not character then return end
        
        -- Collect money every cycle
        collectMoneyFromPads()
        
        -- Wait a bit between checks to avoid spam
        wait(2)
    end)
end

-- Function to stop auto money collection
local function stopMoneyCollection()
    if moneyCollectionConnection then
        moneyCollectionConnection:Disconnect()
        moneyCollectionConnection = nil
    end
end

-- Function to get current upgrade level from GUI
local function getCurrentLevel(upgradeType)
    local success, level = pcall(function()
        local playerGui = player:WaitForChild("PlayerGui")
        local frames = playerGui:WaitForChild("Frames")
        local upgradesFrame = frames:WaitForChild("UpgradesFrame")
        local upgradeList = upgradesFrame:WaitForChild("UpgradeList")
        
        if upgradeType == "Tool" then
            local toolFrame = upgradeList:WaitForChild("Tool")
            local levelFrame = toolFrame:WaitForChild("Level")
            local levelText = levelFrame.Text
            -- Extract number from "Level X" format
            local levelNumber = tonumber(levelText:match("%d+"))
            return levelNumber or 0
        elseif upgradeType == "Luck" then
            local luckFrame = upgradeList:WaitForChild("Luck")
            local levelFrame = luckFrame:WaitForChild("Level")
            local levelText = levelFrame.Text
            -- Extract number from "Level X" format
            local levelNumber = tonumber(levelText:match("%d+"))
            return levelNumber or 0
        end
    end)
    
    if success then
        return level
    else
        return 0
    end
end

-- Function to get player's current cash
local function getCurrentCash()
    local success, cash = pcall(function()
        local leaderstats = player:WaitForChild("leaderstats")
        local cashValue = leaderstats:WaitForChild("Cash")
        return cashValue.Value
    end)
    
    if success then
        return cash
    else
        return 0
    end
end

-- Function to buy upgrade
local function buyUpgrade(upgradeType)
    local success = pcall(function()
        local args = {upgradeType}
        local remotes = ReplicatedStorage:WaitForChild("Remotes")
        local buyUpgradeRemote = remotes:WaitForChild("BuyUpgrade")
        buyUpgradeRemote:FireServer(unpack(args))
    end)
    
    if success then
        return true
    else
        return false
    end
end

-- Function to check and perform upgrades (fixed to prevent spam)
local function checkAndUpgrade()
    if not autoUpgrade or upgradeInProgress then return end
    
    -- Load upgrade data if not cached
    local currentUpgradeData = loadUpgradeData()
    if not currentUpgradeData then
        return
    end
    
    local currentCash = getCurrentCash()
    if currentCash <= 0 then return end
    
    -- Check Tool (Pickaxe) upgrade
    local toolLevel = getCurrentLevel("Tool")
    local nextToolLevel = toolLevel + 1
    
    -- Only upgrade if level changed and we can afford it
    if toolLevel ~= lastToolLevel and currentUpgradeData.Tool and currentUpgradeData.Tool.Levels[nextToolLevel] then
        local toolCost = currentUpgradeData.Tool.Levels[nextToolLevel][2]
        if currentCash >= toolCost then
            upgradeInProgress = true
            if buyUpgrade("Tool") then
                lastToolLevel = toolLevel -- Update tracked level
                WindUI:Notify({
                    Title = "Tool Upgraded",
                    Content = "Pickaxe upgraded to Level " .. nextToolLevel,
                    Duration = 3,
                    Icon = "arrow-up"
                })
                wait(2) -- Wait for upgrade to process
            end
            upgradeInProgress = false
        end
    end
    
    -- Refresh cash after potential Tool purchase
    currentCash = getCurrentCash()
    
    -- Check Luck upgrade
    local luckLevel = getCurrentLevel("Luck")
    local nextLuckLevel = luckLevel + 1
    
    -- Only upgrade if level changed and we can afford it
    if luckLevel ~= lastLuckLevel and currentUpgradeData.Luck and currentUpgradeData.Luck.Levels[nextLuckLevel] then
        local luckCost = currentUpgradeData.Luck.Levels[nextLuckLevel][2]
        if currentCash >= luckCost then
            upgradeInProgress = true
            if buyUpgrade("Luck") then
                lastLuckLevel = luckLevel -- Update tracked level
                WindUI:Notify({
                    Title = "Luck Upgraded",
                    Content = "Luck upgraded to Level " .. nextLuckLevel,
                    Duration = 3,
                    Icon = "star"
                })
                wait(2) -- Wait for upgrade to process
            end
            upgradeInProgress = false
        end
    end
    
    -- Update tracked levels
    if lastToolLevel == -1 then lastToolLevel = toolLevel end
    if lastLuckLevel == -1 then lastLuckLevel = luckLevel end
end

-- Function to start auto upgrade system
local function startAutoUpgrade()
    if upgradeConnection then
        upgradeConnection:Disconnect()
    end
    
    upgradeConnection = RunService.Heartbeat:Connect(function()
        if not autoUpgrade then return end
        
        -- Check for upgrades every few seconds
        checkAndUpgrade()
        wait(3) -- Check every 3 seconds to avoid spam
    end)
end

-- Function to stop auto upgrade system
local function stopAutoUpgrade()
    if upgradeConnection then
        upgradeConnection:Disconnect()
        upgradeConnection = nil
    end
end

-- Function to get player's current characters from backpack
local function getPlayerCharacters()
    local characters = {}
    local backpack = player:WaitForChild("Backpack")
    
    for _, tool in pairs(backpack:GetChildren()) do
        if tool:IsA("Tool") then
            table.insert(characters, tool.Name)
        end
    end
    
    return characters
end

-- Function to check if player has required characters
local function hasRequiredCharacters(requiredCharacters)
    local playerCharacters = getPlayerCharacters()
    
    for _, requiredChar in pairs(requiredCharacters) do
        local hasCharacter = false
        for _, playerChar in pairs(playerCharacters) do
            if playerChar == requiredChar.Id then
                hasCharacter = true
                break
            end
        end
        if not hasCharacter then
            return false, requiredChar.Id
        end
    end
    
    return true, nil
end

-- Function to check rebirth requirements
local function checkRebirthRequirements(rebirthLevel)
    local currentRebirthData = loadRebirthData()
    if not currentRebirthData or not currentRebirthData[rebirthLevel] then
        return false, "No rebirth data for level " .. rebirthLevel
    end
    
    local requirements = currentRebirthData[rebirthLevel].Need
    local currentCash = getCurrentCash()
    
    -- Check each requirement
    for _, requirement in pairs(requirements) do
        if requirement.Type == "Money" then
            if currentCash < requirement.Amount then
                return false, "Need " .. requirement.Amount .. " money, have " .. currentCash
            end
        elseif requirement.Type == "Character" then
            local requiredChars = {}
            for _, req in pairs(requirements) do
                if req.Type == "Character" then
                    table.insert(requiredChars, req)
                end
            end
            
            local hasChars, missingChar = hasRequiredCharacters(requiredChars)
            if not hasChars then
                return false, "Missing character: " .. missingChar
            end
        end
    end
    
    return true, "All requirements met"
end

-- Function to perform rebirth
local function performRebirth(rebirthLevel)
    local success = pcall(function()
        local remotes = ReplicatedStorage:WaitForChild("Remotes")
        local rebirthRemote = remotes:WaitForChild("Rebirth") -- Assuming this is the remote name
        rebirthRemote:FireServer(rebirthLevel)
    end)
    
    if success then
        return true
    else
        return false
    end
end

-- Function to find next available rebirth
local function findNextRebirth()
    local currentRebirthData = loadRebirthData()
    if not currentRebirthData then return nil end
    
    -- Start from rebirth level 1 and find the first one we can do
    for rebirthLevel = 1, 100 do -- Check up to 100 rebirth levels
        if currentRebirthData[rebirthLevel] then
            local canRebirth, reason = checkRebirthRequirements(rebirthLevel)
            if canRebirth then
                return rebirthLevel
            end
        else
            break -- No more rebirth levels available
        end
    end
    
    return nil
end

-- Function to start auto rebirth system (fixed to prevent spam)
local function startAutoRebirth()
    if rebirthConnection then
        rebirthConnection:Disconnect()
    end
    
    rebirthConnection = RunService.Heartbeat:Connect(function()
        if not autoRebirth or rebirthInProgress then return end
        
        local nextRebirthLevel = findNextRebirth()
        if nextRebirthLevel and nextRebirthLevel ~= lastRebirthLevel then
            local canRebirth, reason = checkRebirthRequirements(nextRebirthLevel)
            if canRebirth then
                rebirthInProgress = true
                if performRebirth(nextRebirthLevel) then
                    lastRebirthLevel = nextRebirthLevel -- Track completed rebirth
                    WindUI:Notify({
                        Title = "Rebirth Complete",
                        Content = "Rebirted to level " .. nextRebirthLevel,
                        Duration = 4,
                        Icon = "star"
                    })
                    wait(5) -- Wait longer after rebirth for game to update
                end
                rebirthInProgress = false
            end
        end
        
        -- Initialize tracking if first run
        if lastRebirthLevel == -1 and nextRebirthLevel then
            lastRebirthLevel = nextRebirthLevel - 1 -- Set to one below current available
        end
        
        wait(5) -- Check every 5 seconds
    end)
end

-- Function to stop auto rebirth system
local function stopAutoRebirth()
    if rebirthConnection then
        rebirthConnection:Disconnect()
        rebirthConnection = nil
    end
end

-- Chest Management Functions
local function checkFreeChest()
    local success, timeLeft = pcall(function()
        return workspace:GetAttribute("FreeChestTimeLeft")
    end)
    
    if success and timeLeft then
        return timeLeft <= 0
    end
    return false
end

-- Function to claim free chest
local function claimFreeChest()
    local success = pcall(function()
        game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("ClaimFreeChest"):InvokeServer()
    end)
    
    if success then
        WindUI:Notify({
            Title = "Free Chest Claimed",
            Content = "Successfully claimed free chest",
            Duration = 3,
            Icon = "gift"
        })
    end
    return success
end

-- Function to start auto claim chest system
local function startAutoClaimChest()
    if claimChestConnection then
        claimChestConnection:Disconnect()
    end
    
    claimChestConnection = RunService.Heartbeat:Connect(function()
        if autoClaimChest then
            if checkFreeChest() then
                claimFreeChest()
                wait(1) -- Wait before checking again
            end
        end
    end)
end

-- Function to stop auto claim chest system
local function stopAutoClaimChest()
    if claimChestConnection then
        claimChestConnection:Disconnect()
        claimChestConnection = nil
    end
end

-- Function to get chest stock
local function getChestStock(chestType)
    local success, stock = pcall(function()
        local stockText = game:GetService("Players").LocalPlayer.PlayerGui.Frames.ChestsFrame.ChestList[chestType].Stock.Text
        local stockNumber = stockText:match("x(%d+)")
        return tonumber(stockNumber) or 0
    end)
    
    if success then
        return stock
    end
    return 0
end

-- Function to buy chest
local function buyChest(chestType)
    if not chestData or not chestData[chestType] then
        return false
    end
    
    local chestInfo = chestData[chestType]
    local currentCash = getCurrentCash()
    local stock = getChestStock(chestType)
    
    -- Check if we have enough money and stock is available
    if currentCash >= chestInfo.Price and stock > 0 then
        local success = pcall(function()
            game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("BuyChest"):FireServer(chestType)
        end)
        
        if success then
            WindUI:Notify({
                Title = "Chest Purchased",
                Content = "Bought " .. chestInfo.DisplayName .. " for " .. chestInfo.Price,
                Duration = 3,
                Icon = "shopping-cart"
            })
            return true
        end
    end
    return false
end

-- Function to start auto buy chest system
local function startAutoBuyChest()
    if buyChestConnection then
        buyChestConnection:Disconnect()
    end
    
    buyChestConnection = RunService.Heartbeat:Connect(function()
        if autoBuyChest and selectedChestTypes and #selectedChestTypes > 0 then
            for _, chestType in ipairs(selectedChestTypes) do
                local stock = getChestStock(chestType)
                if stock > 0 then
                    buyChest(chestType)
                    wait(0.5) -- Small wait between purchases
                end
            end
            wait(1) -- Wait before next cycle
        end
    end)
end

-- Function to stop auto buy chest system
local function stopAutoBuyChest()
    if buyChestConnection then
        buyChestConnection:Disconnect()
        buyChestConnection = nil
    end
end

-- Auto Sell Functions
local function scanAndSellCharacters()
    local backpack = game:GetService("Players").LocalPlayer.Backpack
    local soldCount = 0
    
    for _, tool in pairs(backpack:GetChildren()) do
        if tool:IsA("Tool") then
            local characterName = tool:GetAttribute("CharacterName")
            local variant = tool:GetAttribute("Variant")
            local characterId = tool:GetAttribute("CharacterIds")
            
            if characterName and characterId then
                -- Check if this character is in our sell list
                local shouldSell = false
                for _, sellCharacter in ipairs(selectedCharactersToSell) do
                    if characterName == sellCharacter then
                        -- Check gold variant filter
                        if sellGoldVariant == "Both" then
                            shouldSell = true
                        elseif sellGoldVariant == "Gold" and variant == "Gold" then
                            shouldSell = true
                        elseif sellGoldVariant == "NonGold" and variant ~= "Gold" then
                            shouldSell = true
                        end
                        break
                    end
                end
                
                if shouldSell then
                    -- Delete the tool (sell it)
                    tool:Destroy()
                    soldCount = soldCount + 1
                end
            end
        end
    end
    
    if soldCount > 0 then
        WindUI:Notify({
            Title = "Characters Sold",
            Content = "Sold " .. soldCount .. " characters",
            Duration = 2,
            Icon = "dollar-sign"
        })
    end
end

-- Function to start auto sell system
local function startAutoSell()
    if sellConnection then
        sellConnection:Disconnect()
    end
    
    sellConnection = RunService.Heartbeat:Connect(function()
        if autoSell and selectedCharactersToSell and #selectedCharactersToSell > 0 then
            scanAndSellCharacters()
            wait(2) -- Wait 2 seconds between scans
        end
    end)
end

-- Function to stop auto sell system
local function stopAutoSell()
    if sellConnection then
        sellConnection:Disconnect()
        sellConnection = nil
    end
end

-- Main mining loop (the brain of our mining robot!)
local function startMining()
    if miningConnection then
        miningConnection:Disconnect()
    end
    
    miningConnection = RunService.Heartbeat:Connect(function()
        if not autoMining then return end
        
        -- Update character reference if respawned
        character = player.Character
        if not character then return end
        
        humanoid = character:FindFirstChild("Humanoid")
        humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        if not humanoid or not humanoidRootPart then return end
        
        -- ALWAYS check and ensure pickaxe is equipped every cycle!
        if not ensurePickaxeEquipped() then
            wait(1)
            return
        end
        
        -- Find user's plot if not found yet
        if not userPlot then
            userPlot = findUserPlot()
            if not userPlot then return end
        end
        
        -- Check if we should prioritize ServerChest
        if serverChestMode and currentServerChest then
            -- Mine the ServerChest
            currentTarget = currentServerChest
            fireHammer()
        else
            -- Find a valid chest in user's plot
            local chest = findValidChest(userPlot)
            if chest then
                -- If we found a new chest, teleport to it
                if currentTarget ~= chest then
                    currentTarget = chest
                    teleportToChest(chest)
                    wait(0.5) -- Small delay after teleporting
                end
                
                -- Fire the hammer
                fireHammer()
            else
                currentTarget = nil
                -- Wait a bit before checking again
                wait(2)
            end
        end
    end)
end

-- Function to stop mining
local function stopMining()
    if miningConnection then
        miningConnection:Disconnect()
        miningConnection = nil
    end
    stopServerChestMonitoring()
    currentTarget = nil
end

-- Function to stop all activities
local function stopAllActivities()
    stopMining()
    stopMoneyCollection()
    stopAutoUpgrade()
    stopAutoRebirth()
    stopAutoClaimChest()
    stopAutoBuyChest()
    stopAutoSell()
end

-- Create the UI window
local Window = WindUI:CreateWindow({
    Title = "Auto Mining Helper",
    Icon = "rbxassetid://129260712070622",
    IconThemed = true,
    Author = "Mining Assistant",
    Folder = "AutoMining",
    Size = UDim2.fromOffset(500, 400),
    Transparent = true,
    Theme = "Dark",
    User = {
        Enabled = true,
        Anonymous = false
    },
    SideBarWidth = 150,
    ScrollBarEnabled = true,
})

-- Create tabs
local MainTab = Window:Tab({ 
    Title = "Mining Controls", 
    Icon = "pickaxe"
})

local SellTab = Window:Tab({ 
    Title = "Auto Sell", 
    Icon = "dollar-sign"
})

local ConfigTab = Window:Tab({ 
    Title = "Config", 
    Icon = "file-cog"
})

-- Auto Mining Toggle
local autoMiningToggle = MainTab:Toggle({
    Title = "Auto Mining",
    Desc = "Enable automatic mining",
    Value = false,
    Callback = function(state)
        autoMining = state
        if state then
            userPlot = findUserPlot() -- Refresh plot info
            if serverChestMode then
                startServerChestMonitoring()
            end
            startMining()
        else
            stopMining()
        end
    end
})

-- ServerChest Toggle
local serverChestToggle = MainTab:Toggle({
    Title = "ServerChest Mode",
    Desc = "Auto teleport to ServerChest",
    Value = false,
    Callback = function(state)
        serverChestMode = state
        if state then
            if autoMining then
                startServerChestMonitoring()
            end
            WindUI:Notify({
                Title = "ServerChest Mode ON",
                Content = "Will auto teleport to ServerChest",
                Duration = 3,
                Icon = "star"
            })
        else
            stopServerChestMonitoring()
            WindUI:Notify({
                Title = "ServerChest Mode OFF",
                Content = "Back to normal mining",
                Duration = 2,
                Icon = "x"
            })
        end
    end
})

-- Auto Money Collection Toggle
local autoMoneyToggle = MainTab:Toggle({
    Title = "Auto Money Collection",
    Desc = "Collect money from pads",
    Value = false,
    Callback = function(state)
        autoCollectMoney = state
        if state then
            userPlot = findUserPlot() -- Refresh plot info
            startMoneyCollection()
            WindUI:Notify({
                Title = "Money Collection ON",
                Content = "Auto collecting money",
                Duration = 3,
                Icon = "dollar-sign"
            })
        else
            stopMoneyCollection()
            WindUI:Notify({
                Title = "Money Collection OFF",
                Content = "Stopped money collection",
                Duration = 2,
                Icon = "x"
            })
        end
    end
})

-- Auto Upgrade Toggle
local autoUpgradeToggle = MainTab:Toggle({
    Title = "Auto Upgrade",
    Desc = "Auto upgrade Pickaxe and Luck",
    Value = false,
    Callback = function(state)
        autoUpgrade = state
        if state then
            startAutoUpgrade()
            WindUI:Notify({
                Title = "Auto Upgrade ON",
                Content = "Will auto upgrade when affordable",
                Duration = 3,
                Icon = "trending-up"
            })
        else
            stopAutoUpgrade()
            WindUI:Notify({
                Title = "Auto Upgrade OFF",
                Content = "Stopped upgrades",
                Duration = 2,
                Icon = "x"
            })
        end
    end
})

-- Auto Rebirth Toggle
local autoRebirthToggle = MainTab:Toggle({
    Title = "Auto Rebirth",
    Desc = "Auto rebirth when requirements met",
    Value = false,
    Callback = function(state)
        autoRebirth = state
        if state then
            startAutoRebirth()
            WindUI:Notify({
                Title = "Auto Rebirth ON",
                Content = "Will auto rebirth when ready",
                Duration = 3,
                Icon = "refresh-cw"
            })
        else
            stopAutoRebirth()
            WindUI:Notify({
                Title = "Auto Rebirth OFF",
                Content = "Stopped rebirth",
                Duration = 2,
                Icon = "x"
            })
        end
    end
})

MainTab:Section({ Title = "Chest Management", Icon = "gift" })

-- Auto Claim Chest Toggle
local autoClaimChestToggle = MainTab:Toggle({
    Title = "Auto Claim Chest",
    Desc = "Auto claim free chest when ready",
    Value = false,
    Callback = function(state)
        autoClaimChest = state
        if state then
            startAutoClaimChest()
            WindUI:Notify({
                Title = "Auto Claim Chest ON",
                Content = "Will auto claim free chests",
                Duration = 3,
                Icon = "gift"
            })
        else
            stopAutoClaimChest()
            WindUI:Notify({
                Title = "Auto Claim Chest OFF",
                Content = "Stopped claiming chests",
                Duration = 2,
                Icon = "x"
            })
        end
    end
})

-- Auto Buy Chest Toggle
local autoBuyChestToggle = MainTab:Toggle({
    Title = "Auto Buy Chest",
    Desc = "Auto buy selected chest type",
    Value = false,
    Callback = function(state)
        autoBuyChest = state
        if state then
            startAutoBuyChest()
            local chestList = table.concat(selectedChestTypes, ", ")
        else
            stopAutoBuyChest()

        end
    end
})

-- Chest Type Dropdown
local chestDropdown = MainTab:Dropdown({
    Title = "Chest Types",
    Desc = "Select chest types to buy",
    Multi = true,
    AllowNone = false,
    Values = {"Wooden", "Bronze", "Steel", "Crystal", "Shard", "Flame", "Mythic", "Godly", "Ruby", "Emerald"},
    Value = selectedChestTypes,
    Callback = function(values)
        selectedChestTypes = values
        local chestList = table.concat(values, ", ")
        WindUI:Notify({
            Title = "Chest Types Selected",
            Content = "Selected: " .. chestList,
            Duration = 2,
            Icon = "check"
        })
    end
})

MainTab:Divider()

-- Auto Sell Tab Content
SellTab:Section({ Title = "Character Selling", Icon = "users" })

-- Auto Sell Toggle
local autoSellToggle = SellTab:Toggle({
    Title = "Auto Sell",
    Desc = "Auto sell selected characters",
    Value = false,
    Callback = function(state)
        autoSell = state
        if state then
            startAutoSell()
            local characterList = table.concat(selectedCharactersToSell, ", ")
            WindUI:Notify({
                Title = "Auto Sell ON",
                Content = "Will auto sell: " .. characterList,
                Duration = 3,
                Icon = "dollar-sign"
            })
        else
            stopAutoSell()
            WindUI:Notify({
                Title = "Auto Sell OFF",
                Content = "Stopped auto selling",
                Duration = 2,
                Icon = "x"
            })
        end
    end
})

-- Character Selection Dropdown
local characterNames = {}
for characterName, _ in pairs(characterData) do
    table.insert(characterNames, characterName)
end
table.sort(characterNames) -- Sort alphabetically

local characterDropdown = SellTab:Dropdown({
    Title = "Characters to Sell",
    Desc = "Select characters to auto sell",
    Multi = true,
    AllowNone = true,
    Values = characterNames,
    Value = selectedCharactersToSell,
    Callback = function(values)
        selectedCharactersToSell = values
        local characterList = table.concat(values, ", ")
        WindUI:Notify({
            Title = "Characters Selected",
            Content = "Selected: " .. (characterList ~= "" and characterList or "None"),
            Duration = 2,
            Icon = "check"
        })
    end
})

-- Gold/NonGold Filter Dropdown
local goldFilterDropdown = SellTab:Dropdown({
    Title = "Gold Filter",
    Desc = "Choose gold variant filter",
    Multi = false,
    AllowNone = false,
    Values = {"Both", "Gold", "NonGold"},
    Value = sellGoldVariant,
    Callback = function(value)
        sellGoldVariant = value
        WindUI:Notify({
            Title = "Gold Filter Set",
            Content = "Filter: " .. value,
            Duration = 2,
            Icon = "filter"
        })
    end
})


-- Config System with custom Zebux > Unbox Anime path

-- Custom config system with Zebux > Unbox Anime path
local HttpService = game:GetService("HttpService")

local folderPath = "Zebux/Unbox Anime"
makefolder("Zebux")
makefolder(folderPath)

local function SaveConfig()
    local configData = {
        AutoMining = autoMining,
        ServerChestMode = serverChestMode,
        AutoMoneyCollection = autoCollectMoney,
        AutoUpgrade = autoUpgrade,
        AutoRebirth = autoRebirth,
        AutoClaimChest = autoClaimChest,
        AutoBuyChest = autoBuyChest,
        SelectedChestTypes = selectedChestTypes,
        AutoSell = autoSell,
        SelectedCharactersToSell = selectedCharactersToSell,
        SellGoldVariant = sellGoldVariant
    }
    
    local filePath = folderPath .. "/AutoMiningConfig.json"
    local jsonData = HttpService:JSONEncode(configData)
    writefile(filePath, jsonData)
end

local function LoadConfig()
    local filePath = folderPath .. "/AutoMiningConfig.json"
    if isfile(filePath) then
        local jsonData = readfile(filePath)
        local configData = HttpService:JSONDecode(jsonData)
        
        -- Apply loaded settings to toggles
        if configData.AutoMining ~= nil then
            autoMiningToggle:SetValue(configData.AutoMining)
        end
        
        if configData.ServerChestMode ~= nil then
            serverChestToggle:SetValue(configData.ServerChestMode)
        end
        
        if configData.AutoMoneyCollection ~= nil then
            autoMoneyToggle:SetValue(configData.AutoMoneyCollection)
        end
        
        if configData.AutoUpgrade ~= nil then
            autoUpgradeToggle:SetValue(configData.AutoUpgrade)
        end
        
        if configData.AutoRebirth ~= nil then
            autoRebirthToggle:SetValue(configData.AutoRebirth)
        end
        
        if configData.AutoClaimChest ~= nil then
            autoClaimChestToggle:SetValue(configData.AutoClaimChest)
        end
        
        if configData.AutoBuyChest ~= nil then
            autoBuyChestToggle:SetValue(configData.AutoBuyChest)
        end
        
        if configData.SelectedChestTypes ~= nil then
            selectedChestTypes = configData.SelectedChestTypes
            chestDropdown:SetValue(configData.SelectedChestTypes)
        end
        
        if configData.AutoSell ~= nil then
            autoSellToggle:SetValue(configData.AutoSell)
        end
        
        if configData.SelectedCharactersToSell ~= nil then
            selectedCharactersToSell = configData.SelectedCharactersToSell
            characterDropdown:SetValue(configData.SelectedCharactersToSell)
        end
        
        if configData.SellGoldVariant ~= nil then
            sellGoldVariant = configData.SellGoldVariant
            goldFilterDropdown:SetValue(configData.SellGoldVariant)
        end
        
        return true
    end
    return false
end

-- Save button
ConfigTab:Button({
    Title = "Save Config",
    Desc = "Save settings",
    Callback = function()
        SaveConfig()
        WindUI:Notify({
            Title = "Config Saved",
            Content = "Settings saved",
            Duration = 3,
            Icon = "check"
        })
    end
})

-- Load button
ConfigTab:Button({
    Title = "Load Config", 
    Desc = "Load settings",
    Callback = function()
        if LoadConfig() then
            WindUI:Notify({
                Title = "Config Loaded",
                Content = "Settings loaded",
                Duration = 3,
                Icon = "check"
            })
        else
            WindUI:Notify({
                Title = "Load Failed",
                Content = "No config file found",
                Duration = 3,
                Icon = "alert-triangle"
            })
        end
    end
})

-- Auto-load config button
ConfigTab:Button({
    Title = "Auto Load Config",
    Desc = "Auto load config",
    Callback = function()
        if LoadConfig() then
            WindUI:Notify({
                Title = "Auto Config Loaded",
                Content = "Configuration loaded",
                Duration = 3,
                Icon = "refresh-cw"
            })
        else
            WindUI:Notify({
                Title = "Auto Load Failed",
                Content = "No config file found",
                Duration = 3,
                Icon = "alert-triangle"
            })
        end
    end
})

-- Debug button
ConfigTab:Button({
    Title = "Show Config Path",
    Desc = "Show config location",
    Callback = function()
        local filePath = folderPath .. "/AutoMiningConfig.json"
        local exists = isfile(filePath) and "Exists" or "Not Found"
        
        WindUI:Notify({
            Title = "Config Location",
            Content = "Path: " .. folderPath .. "\nFile: AutoMiningConfig.json\nStatus: " .. exists,
            Duration = 5,
            Icon = "info"
        })
    end
})

-- Keybind for pickaxe (Key 1) and UI toggle (Key G)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.One then
        equipPickaxe()
    elseif input.KeyCode == Enum.KeyCode.G then
        Window:Toggle()
    end
end)

-- Handle character respawning
player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    humanoid = character:WaitForChild("Humanoid")
    humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    
    -- Reset plot info when respawning
    userPlot = nil
    currentTarget = nil
end)

-- Stop all activities when leaving game
game.Players.PlayerRemoving:Connect(function(playerWhoLeft)
    if playerWhoLeft == player then
        stopAllActivities()
    end
end)

-- Load upgrade data on script start
loadUpgradeData()

-- Load rebirth data on script start
loadRebirthData()

-- Auto-load config on script start (if available)
pcall(function()
    LoadConfig()
end)

-- Notification when script loads
WindUI:Notify({
    Title = "Auto Mining Loaded",
    Content = "Press G to toggle UI",
    Duration = 6,
    Icon = "check-circle"
})

