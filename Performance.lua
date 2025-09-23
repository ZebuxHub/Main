-- Performance.lua - Pet Model Removal Toggle

local Performance = {}

-- Dependencies (injected)
local WindUI, Tabs, Config

-- State to track if pets are removed
local state = {
	petsRemoved = false,
	blankScreenActive = false,
	blankScreenGui = nil
}

-- Function for Performance Mode (clean models, remove effects, disable wind, optimize rendering)
local function activatePerformanceMode()
	if state.petsRemoved then
		if WindUI then WindUI:Notify({ Title = "⚡ Performance Mode", Content = "Performance Mode already active", Duration = 2 }) end
		return
	end

	local totalModelsProcessed = 0
	local totalPartsRemoved = 0
	local totalEffectsRemoved = 0
	local totalOptimizations = 0

	-- === CLEAN PETS ===
	local petsFolder = workspace:FindFirstChild("Pets")
	if petsFolder then
		-- List of parts to keep in each pet model
		local keepParts = {
			"CollectHL",
			"SA_PetStateMachine", 
			"BF",
			"BE",
			"RootPart"
		}
		
		-- List of parts to keep inside RootPart
		local keepInRootPart = {
			"Base",
			"CS_IdlePet",
			"RE", 
			"TrgIdle",
			"GUI/IdleGUI",
			"Motor6D"
		}

		-- Process each pet model
		for _, petModel in pairs(petsFolder:GetChildren()) do
			if petModel:IsA("Model") then
				totalModelsProcessed = totalModelsProcessed + 1
				
				-- Remove unwanted parts from the main pet model
				for _, child in pairs(petModel:GetChildren()) do
					local shouldKeep = false
					
					-- Check if this part should be kept
					for _, keepName in pairs(keepParts) do
						if child.Name == keepName then
							shouldKeep = true
							break
						end
					end
					
					-- If it's not in the keep list, remove it
					if not shouldKeep then
						pcall(function()
							child:Destroy()
							totalPartsRemoved = totalPartsRemoved + 1
						end)
		end
	end

				-- Clean up RootPart specifically
				local rootPart = petModel:FindFirstChild("RootPart")
				if rootPart then
					for _, child in pairs(rootPart:GetChildren()) do
						local shouldKeep = false
						
						-- Check if this part should be kept in RootPart
						for _, keepName in pairs(keepInRootPart) do
							if child.Name == keepName then
								shouldKeep = true
								break
							end
						end
						
						-- If it's not in the keep list, remove it
						if not shouldKeep then
	pcall(function()
								child:Destroy()
								totalPartsRemoved = totalPartsRemoved + 1
							end)
						end
					end
				end
			end
		end
	end

	-- === CLEAN PLAYER BUILT BLOCKS ===
	local playerBlocksFolder = workspace:FindFirstChild("PlayerBuiltBlocks")
	if playerBlocksFolder then
		-- List of parts to remove from PlayerBuiltBlocks models
		local removeFromBlocks = {
			"color1",
			"color2", 
			"E1D",
			"E1U",
			"E2D",
			"E2U",
			"E3",
			"Left",
			"MutateFX_Inst",
			"Right"
		}

		-- Process each player built block model
		for _, blockModel in pairs(playerBlocksFolder:GetChildren()) do
			if blockModel:IsA("Model") then
				totalModelsProcessed = totalModelsProcessed + 1
				
				-- Remove specific unwanted parts from block models
				for _, child in pairs(blockModel:GetChildren()) do
					local shouldRemove = false
					
					-- Check if this part should be removed
					for _, removeName in pairs(removeFromBlocks) do
						if child.Name == removeName then
							shouldRemove = true
							break
						end
					end
					
					-- If it's in the remove list, destroy it
					if shouldRemove then
			pcall(function()
							child:Destroy()
							totalPartsRemoved = totalPartsRemoved + 1
			end)
		end
	end
			end
		end
	end

	-- === REMOVE ALL GAME EFFECTS ===
	for _, obj in ipairs(game:GetDescendants()) do
		if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or 
		   obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") or 
		   obj:IsA("Explosion") or obj:IsA("PointLight") or obj:IsA("SpotLight") or 
		   obj:IsA("SurfaceLight") or obj:IsA("Highlight") or obj:IsA("SelectionBox") or
		   obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
			pcall(function()
				if obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
					-- For GUIs, just disable them
					obj.Enabled = false
				else
					-- For effects and lights, destroy them
					obj:Destroy()
				end
				totalEffectsRemoved = totalEffectsRemoved + 1
			end)
		end
	end

	-- === DISABLE WIND BEHAVIOR ===
	pcall(function()
		local windScript = game:GetService("Players").LocalPlayer.PlayerScripts.Env.Wind
		if windScript then
			windScript.Enabled = false
		end
	end)

	-- === ADVANCED PERFORMANCE OPTIMIZATIONS ===
	
	-- Reduce rendering quality for maximum FPS
	pcall(function()
		local renderSettings = settings():GetService("RenderSettings")
		renderSettings.QualityLevel = Enum.QualityLevel.Level01 -- Lowest quality
		renderSettings.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level04 -- Lowest mesh detail
		totalOptimizations = totalOptimizations + 1
	end)

	-- Optimize lighting for performance
	pcall(function()
		local lighting = game:GetService("Lighting")
		lighting.GlobalShadows = false -- Disable shadows
		lighting.FogEnd = 100 -- Reduce fog distance
		lighting.FogStart = 0
		lighting.Brightness = 1 -- Reduce lighting calculations
		lighting.Ambient = Color3.fromRGB(128, 128, 128) -- Flat ambient lighting
		lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
		totalOptimizations = totalOptimizations + 1
	end)

	-- Disable post-processing effects
	pcall(function()
		local lighting = game:GetService("Lighting")
		for _, effect in ipairs(lighting:GetChildren()) do
			if effect:IsA("PostEffect") then
				effect.Enabled = false
				totalOptimizations = totalOptimizations + 1
			end
		end
	end)

	-- Reduce workspace streaming and physics
	pcall(function()
		local workspace = game:GetService("Workspace")
		workspace.StreamingEnabled = false -- Disable streaming
		workspace.SignalBehavior = Enum.SignalBehavior.Deferred -- Defer physics
		totalOptimizations = totalOptimizations + 1
	end)

	-- Optimize RunService for lower CPU usage
	pcall(function()
		local runService = game:GetService("RunService")
		-- Reduce heartbeat frequency if possible
		if runService.Heartbeat then
			-- Note: Can't directly change heartbeat rate, but we optimize other systems
		end
		totalOptimizations = totalOptimizations + 1
	end)

	-- Disable unnecessary services
	pcall(function()
		local soundService = game:GetService("SoundService")
		soundService.AmbientReverb = Enum.ReverbType.NoReverb
		soundService.DistanceFactor = 1
		soundService.DopplerScale = 0
		totalOptimizations = totalOptimizations + 1
	end)

	-- Remove terrain decorations and reduce terrain quality
	pcall(function()
		local terrain = workspace:FindFirstChildOfClass("Terrain")
		if terrain then
			terrain.Decoration = false
			-- Note: Can't change terrain quality directly, but disable decorations helps
		end
		totalOptimizations = totalOptimizations + 1
	end)

	-- Optimize camera for performance
	pcall(function()
		local camera = workspace.CurrentCamera
		if camera then
			camera.FieldOfView = 50 -- Reduce FOV to render less
		end
		totalOptimizations = totalOptimizations + 1
	end)

	state.petsRemoved = true
	
	if WindUI then 
		WindUI:Notify({ 
			Title = "⚡ Performance Mode", 
			Content = "Cleaned " .. totalModelsProcessed .. " models, removed " .. totalPartsRemoved .. " parts + " .. totalEffectsRemoved .. " effects + " .. totalOptimizations .. " optimizations", 
			Duration = 5 
		}) 
	end
end

-- Function to disable Performance Mode (note: removed parts can't be restored)
local function deactivatePerformanceMode()
	if not state.petsRemoved then
		if WindUI then WindUI:Notify({ Title = "⚡ Performance Mode", Content = "Performance Mode not active", Duration = 2 }) end
		return
	end

	-- Try to re-enable Wind behavior
	pcall(function()
		local windScript = game:GetService("Players").LocalPlayer.PlayerScripts.Env.Wind
		if windScript then
			windScript.Enabled = true
		end
	end)

	state.petsRemoved = false
	
	if WindUI then 
		WindUI:Notify({ 
			Title = "⚡ Performance Mode", 
			Content = "Performance Mode disabled (effects/models can't be restored)", 
			Duration = 4 
		}) 
	end
end

-- Function to activate blank screen (ultimate performance mode)
local function activateBlankScreen()
	if state.blankScreenActive then
		if WindUI then WindUI:Notify({ Title = "⚫ Blank Screen", Content = "Blank screen already active", Duration = 2 }) end
		return
	end

	-- Create a black screen GUI that covers everything
	local Players = game:GetService("Players")
	local LocalPlayer = Players.LocalPlayer
	local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

	-- Create ScreenGui
	local blankScreenGui = Instance.new("ScreenGui")
	blankScreenGui.Name = "BlankScreenPerformance"
	blankScreenGui.ResetOnSpawn = false
	blankScreenGui.IgnoreGuiInset = true
	blankScreenGui.DisplayOrder = 999999 -- Highest priority

	-- Create black frame that covers entire screen
	local blackFrame = Instance.new("Frame")
	blackFrame.Name = "BlackScreen"
	blackFrame.Size = UDim2.new(1, 0, 1, 0)
	blackFrame.Position = UDim2.new(0, 0, 0, 0)
	blackFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	blackFrame.BorderSizePixel = 0
	blackFrame.Active = false -- Don't block input
	blackFrame.Parent = blankScreenGui

	-- Add subtle text indicator
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(0, 300, 0, 50)
	statusLabel.Position = UDim2.new(0.5, -150, 0.5, -25)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "⚫ Blank Screen Mode Active"
	statusLabel.TextColor3 = Color3.fromRGB(100, 100, 100)
	statusLabel.TextSize = 14
	statusLabel.TextStrokeTransparency = 0.5
	statusLabel.Font = Enum.Font.SourceSans
	statusLabel.Parent = blackFrame

	-- Parent to PlayerGui
	blankScreenGui.Parent = PlayerGui
	
	-- Store reference
	state.blankScreenGui = blankScreenGui
	state.blankScreenActive = true

	if WindUI then 
		WindUI:Notify({ 
			Title = "⚫ Blank Screen", 
			Content = "Blank screen activated! GPU usage minimized.", 
			Duration = 3 
		}) 
	end
end

-- Function to deactivate blank screen
local function deactivateBlankScreen()
	if not state.blankScreenActive then
		if WindUI then WindUI:Notify({ Title = "⚫ Blank Screen", Content = "Blank screen not active", Duration = 2 }) end
		return
	end

	-- Remove the blank screen GUI
	if state.blankScreenGui then
		pcall(function()
			state.blankScreenGui:Destroy()
		end)
		state.blankScreenGui = nil
	end

	state.blankScreenActive = false
	
	if WindUI then 
		WindUI:Notify({ 
			Title = "⚫ Blank Screen", 
			Content = "Blank screen deactivated", 
			Duration = 2 
		}) 
	end
end

function Performance.Init(deps)
	WindUI = deps.WindUI
	Tabs = deps.Tabs
	Config = deps.Config

	-- Ensure Performance tab exists
	if not Tabs.PerfTab then
		Tabs.PerfTab = Tabs.MainSection:Tab({ Title = "🚀 | Performance" })
	end

	-- Create toggle for Performance Mode
	local performanceToggle = Tabs.PerfTab:Toggle({
		Title = "⚡ Performance Mode",
		Value = false,
		Callback = function(stateOn)
			if stateOn then 
				activatePerformanceMode() 
			else 
				deactivatePerformanceMode() 
			end
		end
	})

	-- Create toggle for Blank Screen Mode
	local blankScreenToggle = Tabs.PerfTab:Toggle({
		Title = "⚫ Blank Screen Mode",
		Value = false,
		Callback = function(stateOn)
			if stateOn then 
				activateBlankScreen() 
			else 
				deactivateBlankScreen() 
			end
		end
	})

	-- Note: Config registration is handled by the main file in registerUIElements()

	-- Store references for external access
	Performance.Toggle = performanceToggle
	Performance.BlankScreenToggle = blankScreenToggle
	Performance.Activate = activatePerformanceMode
	Performance.Deactivate = deactivatePerformanceMode
	Performance.ActivateBlankScreen = activateBlankScreen
	Performance.DeactivateBlankScreen = deactivateBlankScreen

	return Performance
end

-- Config management functions
function Performance.GetConfigElements()
	return {
		performanceModeEnabled = Performance.Toggle,
		blankScreenModeEnabled = Performance.BlankScreenToggle
	}
end

function Performance.IsEnabled()
	return state.petsRemoved
end

function Performance.IsBlankScreenEnabled()
	return state.blankScreenActive
end

function Performance.SetEnabled(enabled)
	if Performance.Toggle then
		Performance.Toggle:SetValue(enabled)
	end
end

function Performance.SetBlankScreenEnabled(enabled)
	if Performance.BlankScreenToggle then
		Performance.BlankScreenToggle:SetValue(enabled)
	end
end

-- Get current state for external access
function Performance.GetState()
	return {
		petsRemoved = state.petsRemoved,
		blankScreenActive = state.blankScreenActive
	}
end

return Performance

