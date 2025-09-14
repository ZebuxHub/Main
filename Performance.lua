-- Performance.lua - Performance Mode Toggle

local Performance = {}

-- Services
local Players = game:GetService("Players")

-- Dependencies (injected)
local WindUI, Tabs

-- State to track if performance mode is active
local state = {
	performanceModeActive = false,
	windScriptDisabled = false
}

-- Function to enable performance mode (clean models, remove effects, disable wind)
local function enablePerformanceMode()
	if state.performanceModeActive then
		if WindUI then WindUI:Notify({ Title = "⚡ Performance Mode", Content = "Performance Mode already active", Duration = 2 }) end
		return
	end

	local totalModelsProcessed = 0
	local totalPartsRemoved = 0
	local totalEffectsRemoved = 0

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

	-- === REMOVE ALL GAME EFFECTS ===
	for _, obj in ipairs(game:GetDescendants()) do
		-- Remove visual effects
		if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or 
		   obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") or 
		   obj:IsA("Explosion") or obj:IsA("Highlight") then
			pcall(function()
				obj:Destroy()
				totalEffectsRemoved = totalEffectsRemoved + 1
			end)
		-- Remove lighting effects
		elseif obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
			pcall(function()
				obj:Destroy()
				totalEffectsRemoved = totalEffectsRemoved + 1
			end)
		-- Remove post effects
		elseif obj:IsA("BloomEffect") or obj:IsA("BlurEffect") or obj:IsA("ColorCorrectionEffect") or
			   obj:IsA("DepthOfFieldEffect") or obj:IsA("SunRaysEffect") then
	pcall(function()
				obj:Destroy()
				totalEffectsRemoved = totalEffectsRemoved + 1
	end)
		-- Remove sound effects
		elseif obj:IsA("Sound") then
	pcall(function()
				obj:Stop()
				obj:Destroy()
				totalEffectsRemoved = totalEffectsRemoved + 1
			end)
		end
	end

	-- === DISABLE WIND BEHAVIOR ===
	local localPlayer = Players.LocalPlayer
	if localPlayer then
		local windScript = localPlayer:FindFirstChild("PlayerScripts")
		if windScript then
			windScript = windScript:FindFirstChild("Env")
			if windScript then
				windScript = windScript:FindFirstChild("Wind")
				if windScript then
					pcall(function()
						windScript.Disabled = true
						state.windScriptDisabled = true
					end)
				end
			end
		end
	end

	state.performanceModeActive = true
	
	if WindUI then 
		WindUI:Notify({ 
			Title = "⚡ Performance Mode", 
			Content = "ENABLED: " .. totalModelsProcessed .. " models cleaned, " .. totalPartsRemoved .. " parts removed, " .. totalEffectsRemoved .. " effects removed, Wind disabled", 
			Duration = 5 
		}) 
	end
end

-- Function to disable performance mode (note: removed parts/effects can't be restored)
local function disablePerformanceMode()
	if not state.performanceModeActive then
		if WindUI then WindUI:Notify({ Title = "⚡ Performance Mode", Content = "Performance Mode not active", Duration = 2 }) end
		return
	end

	-- Try to re-enable Wind script if it was disabled
	if state.windScriptDisabled then
		local localPlayer = Players.LocalPlayer
		if localPlayer then
			local windScript = localPlayer:FindFirstChild("PlayerScripts")
			if windScript then
				windScript = windScript:FindFirstChild("Env")
				if windScript then
					windScript = windScript:FindFirstChild("Wind")
					if windScript then
						pcall(function()
							windScript.Disabled = false
							state.windScriptDisabled = false
						end)
					end
				end
			end
		end
	end

	state.performanceModeActive = false
	
	if WindUI then 
		WindUI:Notify({ 
			Title = "⚡ Performance Mode", 
			Content = "DISABLED: Wind re-enabled (removed parts/effects can't be restored)", 
			Duration = 4 
		}) 
	end
end

function Performance.Init(deps)
	WindUI = deps.WindUI
	Tabs = deps.Tabs

	-- Ensure Performance tab exists
	if not Tabs.PerfTab then
		Tabs.PerfTab = Tabs.MainSection:Tab({ Title = "🚀 | Performance" })
	end

	-- Create toggle for performance mode
	local performanceToggle = Tabs.PerfTab:Toggle({
		Title = "⚡ Performance Mode",
		Desc = "Clean models, remove all effects, disable wind - Maximum performance boost",
		Value = false,
		Callback = function(stateOn)
			if stateOn then 
				enablePerformanceMode() 
			else 
				disablePerformanceMode() 
			end
		end
	})

	-- Store references for external access
	Performance.Toggle = performanceToggle
	Performance.Enable = enablePerformanceMode
	Performance.Disable = disablePerformanceMode

	return Performance
end

return Performance


