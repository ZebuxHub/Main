-- AutoHatch.lua - Auto Egg Hatching System for Build A Zoo  
-- Author: Zebux

local AutoHatch = {}
local Core = loadstring(game:HttpGet("https://raw.githubusercontent.com/ZebuxHub/Main/refs/heads/main/Core.lua"))()

-- Auto state variables
local autoHatchEnabled = false
local autoHatchThread = nil

-- UI elements (to be set by main script)
local autoHatchToggle = nil

-- Text checking helpers
local function isStringEmpty(s)
    return type(s) == "string" and (s == "" or s:match("^%s*$") ~= nil)
end

local function isReadyText(text)
    if type(text) ~= "string" then return false end
    -- Empty or whitespace means ready
    if isStringEmpty(text) then return true end
    -- Percent text like "100%", "100.0%", "100.00%" also counts as ready
    local num = text:match("^%s*(%d+%.?%d*)%s*%%%s*$")
    if num then
        local n = tonumber(num)
        if n and n >= 100 then return true end
    end
    -- Words that often mean ready
    local lower = string.lower(text)
    if string.find(lower, "hatch", 1, true) or string.find(lower, "ready", 1, true) then
        return true
    end
    return false
end

-- Check if an egg is ready to hatch
local function isHatchReady(model)
    -- Look for TimeBar/TXT text being empty anywhere under the model
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("TextLabel") and d.Name == "TXT" then
            local parent = d.Parent
            if parent and parent.Name == "TimeBar" then
                if isReadyText(d.Text) then
                    return true
                end
            end
        end
        if d:IsA("ProximityPrompt") and type(d.ActionText) == "string" then
            local at = string.lower(d.ActionText)
            if string.find(at, "hatch", 1, true) then
                return true
            end
        end
    end
    return false
end

-- Collect owned eggs from workspace
local function collectOwnedEggs()
    local owned = {}
    local container = workspace:FindFirstChild("PlayerBuiltBlocks")
    if not container then
        -- No PlayerBuiltBlocks found
        return owned
    end
    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("Model") and Core.playerOwnsInstance(child) then
            table.insert(owned, child)
        end
    end
    -- also allow owned nested models (fallback)
    if #owned == 0 then
        for _, child in ipairs(container:GetDescendants()) do
            if child:IsA("Model") and Core.playerOwnsInstance(child) then
                table.insert(owned, child)
            end
        end
    end
    return owned
end

-- Filter eggs that are ready to hatch
local function filterReadyEggs(models)
    local ready = {}
    for _, m in ipairs(models or {}) do
        if isHatchReady(m) then table.insert(ready, m) end
    end
    return ready
end

-- Try to hatch a specific model
local function tryHatchModel(model)
    -- Double-check ownership before proceeding
    if not Core.playerOwnsInstance(model) then
        return false, "Not owner"
    end
    -- Find a ProximityPrompt named "E" or any prompt on the model
    local prompt
    -- Prefer a prompt on a part named Prompt or with ActionText that implies hatch
    for _, inst in ipairs(model:GetDescendants()) do
        if inst:IsA("ProximityPrompt") then
            prompt = inst
            if inst.ActionText and string.len(inst.ActionText) > 0 then break end
        end
    end
    if not prompt then return false, "No prompt" end
    local pos = Core.getModelPosition(model)
    if not pos then return false, "No position" end
    Core.walkTo(pos, 6)
    -- Ensure we are within MaxActivationDistance by nudging forward if necessary
    local hrp = Core.LocalPlayer.Character and Core.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp and (hrp.Position - pos).Magnitude > (prompt.MaxActivationDistance or 10) - 1 then
        local dir = (pos - hrp.Position).Unit
        hrp.CFrame = CFrame.new(pos - dir * 1.5, pos)
        task.wait(0.1)
    end
    local ok = Core.pressPromptE(prompt)
    return ok
end

-- Main auto hatch loop
local function runAutoHatch()
    while autoHatchEnabled do
        local ok, err = pcall(function()
            local owned = collectOwnedEggs()
            if #owned == 0 then
                task.wait(1.0)
                return
            end
            local eggs = filterReadyEggs(owned)
            if #eggs == 0 then
                task.wait(0.8)
                return
            end
            -- Try nearest first
            local me = Core.getPlayerRootPosition()
            table.sort(eggs, function(a, b)
                local pa = Core.getModelPosition(a) or Vector3.new()
                local pb = Core.getModelPosition(b) or Vector3.new()
                return (pa - me).Magnitude < (pb - me).Magnitude
            end)
            for _, m in ipairs(eggs) do
                -- Moving to hatch
                tryHatchModel(m)
                task.wait(0.2)
            end
            -- Done
        end)
        if not ok then
            warn("Auto Hatch error: " .. tostring(err))
            task.wait(1)
        end
    end
end

-- Create UI elements
function AutoHatch.CreateUI(WindUI, Tabs)
    autoHatchToggle = Tabs.HatchTab:Toggle({
        Title = "⚡ Auto Hatch Eggs",
        Desc = "Automatically hatches your eggs by walking to them",
        Value = false,
        Callback = function(state)
            autoHatchEnabled = state
            
            Core.waitForSettingsReady(0.2)
            if state and not autoHatchThread then
                autoHatchThread = task.spawn(function()
                    runAutoHatch()
                    autoHatchThread = nil
                end)
                WindUI:Notify({ Title = "⚡ Auto Hatch", Content = "Started hatching eggs! 🎉", Duration = 3 })
            elseif (not state) and autoHatchThread then
                WindUI:Notify({ Title = "⚡ Auto Hatch", Content = "Stopped", Duration = 3 })
            end
        end
    })

    Tabs.HatchTab:Button({
        Title = "⚡ Hatch Nearest Egg",
        Desc = "Hatch the closest egg to you",
        Callback = function()
            local owned = collectOwnedEggs()
            if #owned == 0 then
                WindUI:Notify({ Title = "⚡ Auto Hatch", Content = "No eggs found", Duration = 3 })
                return
            end
            local eggs = filterReadyEggs(owned)
            if #eggs == 0 then
                WindUI:Notify({ Title = "⚡ Auto Hatch", Content = "No eggs ready", Duration = 3 })
                return
            end
            local me = Core.getPlayerRootPosition() or Vector3.new()
            table.sort(eggs, function(a, b)
                local pa = Core.getModelPosition(a) or Vector3.new()
                local pb = Core.getModelPosition(b) or Vector3.new()
                return (pa - me).Magnitude < (pb - me).Magnitude
            end)
            -- Moving to hatch
            local ok = tryHatchModel(eggs[1])
            WindUI:Notify({ Title = ok and "🎉 Hatched!" or "❌ Hatch Failed", Content = eggs[1].Name, Duration = 3 })
        end
    })
end

-- Get UI elements for config registration
function AutoHatch.GetUIElements()
    return {
        autoHatchToggle = autoHatchToggle
    }
end

-- Cleanup function
function AutoHatch.Cleanup()
    autoHatchEnabled = false
    if autoHatchThread then
        task.cancel(autoHatchThread)
        autoHatchThread = nil
    end
end

return AutoHatch
