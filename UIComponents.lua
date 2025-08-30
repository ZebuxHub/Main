-- UIComponents.lua - Reusable UI Components for Build A Zoo
-- Author: Zebux
-- Version: 2.0

local UIComponents = {}

-- Services
local UserInputService = game:GetService("UserInputService")

-- Module variables
local WindUI = nil

-- Anti-AFK System
local antiAFKEnabled = false
local antiAFKConnection = nil

function UIComponents.setupAntiAFK()
    if antiAFKEnabled then return end
    antiAFKEnabled = true
    antiAFKConnection = game:GetService("Players").LocalPlayer.Idled:Connect(function()
        game:GetService("VirtualUser"):Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        game:GetService("VirtualUser"):Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    end)
    WindUI:Notify({ Title = "🛡️ Anti-AFK", Content = "Anti-AFK activated!", Duration = 3 })
end

function UIComponents.disableAntiAFK()
    if not antiAFKEnabled then return end
    antiAFKEnabled = false
    if antiAFKConnection then
        antiAFKConnection:Disconnect()
        antiAFKConnection = nil
    end
    WindUI:Notify({ Title = "🛡️ Anti-AFK", Content = "Anti-AFK deactivated.", Duration = 3 })
end

-- Create Anti-AFK Toggle Button
function UIComponents.createAntiAFKButton(Tabs)
    return Tabs.SaveTab:Button({
        Title = "🛡️ Toggle Anti-AFK",
        Desc = "Enable or disable the built-in anti-AFK system",
        Callback = function()
            if antiAFKEnabled then
                UIComponents.disableAntiAFK()
            else
                UIComponents.setupAntiAFK()
            end
        end
    })
end

-- Create Notification Helper
function UIComponents.notify(title, content, duration)
    if WindUI then
        WindUI:Notify({
            Title = title,
            Content = content,
            Duration = duration or 3
        })
    end
end

-- Create Status Display Component
function UIComponents.createStatusDisplay(parent, title, initialDesc, icon)
    return parent:Paragraph({
        Title = title,
        Desc = initialDesc or "Initializing...",
        Image = icon or "activity",
        ImageSize = 16,
    })
end

-- Create Enhanced Toggle with Stats
function UIComponents.createEnhancedToggle(parent, config)
    local toggle = parent:Toggle({
        Title = config.title,
        Desc = config.desc,
        Value = config.defaultValue or false,
        Callback = config.callback
    })
    
    if config.statsCallback then
        -- Create stats display
        local statsLabel = parent:Paragraph({
            Title = config.title .. " Statistics",
            Desc = "No data yet...",
            Image = "bar-chart",
            ImageSize = 14,
        })
        
        -- Start stats update loop
        task.spawn(function()
            while true do
                if config.enabled and config.enabled() then
                    local stats = config.statsCallback()
                    if stats and statsLabel.SetDesc then
                        statsLabel:SetDesc(stats)
                    end
                end
                task.wait(2)
            end
        end)
    end
    
    return toggle
end

-- Create Reset Button
function UIComponents.createResetButton(parent, title, desc, resetCallback)
    return parent:Button({
        Title = title,
        Desc = desc,
        Callback = function()
            if resetCallback then
                resetCallback()
            end
            UIComponents.notify("🔄 Reset Complete", "Data has been reset successfully!", 2)
        end
    })
end

-- Create Section Helper
function UIComponents.createSection(parent, title, icon, opened)
    return parent:Section({
        Title = title,
        Icon = icon,
        Opened = opened ~= false -- Default to true unless explicitly false
    })
end

-- Create Dropdown Helper with Enhanced Options
function UIComponents.createDropdown(parent, config)
    return parent:Dropdown({
        Title = config.title,
        Desc = config.desc,
        Values = config.values,
        Value = config.defaultValue or {},
        Multi = config.multi or false,
        AllowNone = config.allowNone or true,
        Callback = config.callback
    })
end

-- Create Slider Helper with Value Format
function UIComponents.createSlider(parent, config)
    return parent:Slider({
        Title = config.title,
        Desc = config.desc,
        Value = {
            Min = config.min,
            Max = config.max,
            Default = config.default,
        },
        Step = config.step,
        Callback = config.callback
    })
end

-- Create Button Helper
function UIComponents.createButton(parent, title, desc, callback, icon)
    local buttonConfig = {
        Title = title,
        Desc = desc,
        Callback = callback
    }
    
    if icon then
        buttonConfig.Icon = icon
    end
    
    return parent:Button(buttonConfig)
end

-- Create Input Helper
function UIComponents.createInput(parent, config)
    return parent:Input({
        Title = config.title,
        Desc = config.desc,
        Value = config.defaultValue or "",
        Placeholder = config.placeholder,
        Type = config.type or "Input", -- or "Textarea"
        Callback = config.callback
    })
end

-- Create Progress Display
function UIComponents.createProgressDisplay(parent, title, maxValue)
    local display = parent:Paragraph({
        Title = title,
        Desc = "0 / " .. maxValue .. " (0%)",
        Image = "trending-up",
        ImageSize = 16,
    })
    
    return {
        update = function(current)
            local percentage = math.floor((current / maxValue) * 100)
            local desc = current .. " / " .. maxValue .. " (" .. percentage .. "%)"
            if display.SetDesc then
                display:SetDesc(desc)
            end
        end,
        element = display
    }
end

-- Create Collapsible Content
function UIComponents.createCollapsibleContent(parent, title, icon, content)
    local section = UIComponents.createSection(parent, title, icon, false)
    
    for _, item in ipairs(content) do
        if item.type == "button" then
            UIComponents.createButton(section, item.title, item.desc, item.callback, item.icon)
        elseif item.type == "toggle" then
            section:Toggle({
                Title = item.title,
                Desc = item.desc,
                Value = item.defaultValue or false,
                Callback = item.callback
            })
        elseif item.type == "paragraph" then
            section:Paragraph({
                Title = item.title,
                Desc = item.desc,
                Image = item.icon,
                ImageSize = item.iconSize or 16
            })
        end
    end
    
    return section
end

-- Create Tabbed Interface Helper
function UIComponents.createTabbedInterface(window, tabs)
    local createdTabs = {}
    
    for _, tabConfig in ipairs(tabs) do
        local tab = window:Tab({
            Title = tabConfig.title,
            Icon = tabConfig.icon,
            Desc = tabConfig.desc
        })
        
        createdTabs[tabConfig.name] = tab
        
        if tabConfig.content then
            for _, item in ipairs(tabConfig.content) do
                -- Create content based on type
                if item.type == "section" then
                    UIComponents.createSection(tab, item.title, item.icon, item.opened)
                elseif item.type == "button" then
                    UIComponents.createButton(tab, item.title, item.desc, item.callback, item.icon)
                end
            end
        end
    end
    
    return createdTabs
end

-- Format Numbers with Suffixes
function UIComponents.formatNumber(number)
    if number >= 1000000000 then
        return string.format("%.1fB", number / 1000000000)
    elseif number >= 1000000 then
        return string.format("%.1fM", number / 1000000)
    elseif number >= 1000 then
        return string.format("%.1fK", number / 1000)
    else
        return tostring(number)
    end
end

-- Format Time Duration
function UIComponents.formatTime(seconds)
    if seconds < 60 then
        return seconds .. "s"
    elseif seconds < 3600 then
        return math.floor(seconds / 60) .. "m " .. (seconds % 60) .. "s"
    else
        local hours = math.floor(seconds / 3600)
        local minutes = math.floor((seconds % 3600) / 60)
        return hours .. "h " .. minutes .. "m"
    end
end

-- Create Loading Indicator
function UIComponents.createLoadingIndicator(parent, title)
    local indicator = parent:Paragraph({
        Title = title,
        Desc = "Loading...",
        Image = "loader",
        ImageSize = 16,
    })
    
    local dots = 0
    local loadingText = "Loading"
    
    local updateTask = task.spawn(function()
        while indicator do
            dots = (dots + 1) % 4
            local dotsText = string.rep(".", dots)
            if indicator.SetDesc then
                indicator:SetDesc(loadingText .. dotsText)
            end
            task.wait(0.5)
        end
    end)
    
    return {
        finish = function(message)
            if updateTask then
                task.cancel(updateTask)
            end
            if indicator.SetDesc then
                indicator:SetDesc(message or "Complete!")
            end
        end,
        element = indicator
    }
end

-- Initialize function
function UIComponents.Init(dependencies)
    WindUI = dependencies.WindUI
    
    return UIComponents
end

return UIComponents
