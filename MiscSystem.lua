local UIToggleButton = {}

local Players = game:GetService("Players")

local function ensureGuiFolder()
	local pg = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if not pg then
		pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	end
	local holder = pg:FindFirstChild("ZebuxUIToggle")
	if not holder then
		holder = Instance.new("ScreenGui")
		holder.Name = "ZebuxUIToggle"
		holder.ResetOnSpawn = false
		holder.IgnoreGuiInset = true
		holder.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		holder.Parent = pg
	end
	return holder
end

local function createButton(parent)
	local btn = Instance.new("TextButton")
	btn.Name = "ToggleUI"
	btn.AnchorPoint = Vector2.new(1, 0)
	btn.Position = UDim2.new(1, -14, 0, 14)
	btn.Size = UDim2.new(0, 90, 0, 28)
	btn.BackgroundTransparency = 0.2
	btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	btn.BorderSizePixel = 0
	btn.TextColor3 = Color3.fromRGB(235, 235, 235)
	btn.Font = Enum.Font.GothamSemibold
	btn.TextSize = 13
	btn.Text = "Toggle UI"
	btn.AutoButtonColor = true
	btn.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Color = Color3.fromRGB(70, 70, 70)
	stroke.Parent = btn

	return btn
end

local function resolveWindowContainer(WindUI)
	-- Prefer toggling the whole ScreenGui when possible
	if WindUI and WindUI.ScreenGui then
		return WindUI.ScreenGui
	end
	return nil
end

function UIToggleButton.Init(deps)
	local WindUI = deps.WindUI
	local Window = deps.Window

	local holder = ensureGuiFolder()
	local btn = holder:FindFirstChild("ToggleUI") or createButton(holder)

	local function getVisible()
		local container = resolveWindowContainer(WindUI)
		if container and container:IsA("ScreenGui") then
			return container.Enabled ~= false
		end
		if container and container.Visible ~= nil then
			return container.Visible
		end
		if Window and Window.Visible ~= nil then
			return Window.Visible
		end
		return true
	end

	local function setVisible(v)
		local container = resolveWindowContainer(WindUI)
		if container and container:IsA("ScreenGui") then
			container.Enabled = v and true or false
			return
		end
		if container and container.Visible ~= nil then
			container.Visible = v and true or false
			return
		end
		if Window and Window.Visible ~= nil then
			Window.Visible = v and true or false
		end
	end

	local function refreshButton()
		btn.Text = getVisible() and "Hide UI" or "Show UI"
	end

	btn.MouseButton1Click:Connect(function()
		setVisible(not getVisible())
		refreshButton()
	end)

	-- Optional keybind: RightControl toggles UI
	local UIS = game:GetService("UserInputService")
	UIS.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.KeyCode == Enum.KeyCode.RightControl then
			setVisible(not getVisible())
			refreshButton()
		end
	end)

	refreshButton()

	return {
		Button = btn,
		SetVisible = setVisible,
		GetVisible = getVisible,
	}
end

return UIToggleButton


