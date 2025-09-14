-- Performance.lua - Performance Mode with Config Save

local Performance = {}

-- Services
local HttpService = game:GetService("HttpService")

-- Dependencies (injected)
local WindUI, Tabs

-- Config file name
local CONFIG_FILE = "PerformanceMode_Config.json"

-- State to track if performance mode is active
local state = {
	petsRemoved = false
}

-- Default config
local defaultConfig = {
	performanceModeEnabled = false
}

-- Save config to file
local function saveConfig()
	local config = {
		performanceModeEnabled = state.petsRemoved
	}
	
	pcall(function()
		writefile(CONFIG_FILE, HttpService:JSONEncode(config))
	end)
end

-- Load config from file
local function loadConfig()
	local config = defaultConfig
	
	pcall(function()
		if isfile(CONFIG_FILE) then
			local fileContent = readfile(CONFIG_FILE)
			config = HttpService:JSONDecode(fileContent)
		end
	end)
	
	return config
end

-- Function for Performance Mode (clean models, remove effects, disable wind)
local function activatePerformanceMode()
	if state.petsRemoved then
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

	state.petsRemoved = true
	saveConfig() -- Save the new state
	
	if WindUI then 
		WindUI:Notify({ 
			Title = "⚡ Performance Mode", 
			Content = "Cleaned " .. totalModelsProcessed .. " models, removed " .. totalPartsRemoved .. " parts + " .. totalEffectsRemoved .. " effects", 
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
	saveConfig() -- Save the new state
	
	if WindUI then 
		WindUI:Notify({ 
			Title = "⚡ Performance Mode", 
			Content = "Performance Mode disabled (effects/models can't be restored)", 
			Duration = 4 
		}) 
	end
end

function Performance.Init(deps)
	WindUI = deps.WindUI
	Tabs = deps.Tabs

	-- Load saved config
	local config = loadConfig()
	
	-- Ensure Performance tab exists
	if not Tabs.PerfTab then
		Tabs.PerfTab = Tabs.MainSection:Tab({ Title = "🚀 | Performance" })
	end

	-- Create toggle for Performance Mode
	local performanceToggle = Tabs.PerfTab:Toggle({
		Title = "⚡ Performance Mode",
		Value = config.performanceModeEnabled, -- Load saved state
		Callback = function(stateOn)
			if stateOn then 
				activatePerformanceMode() 
			else 
				deactivatePerformanceMode() 
			end
		end
	})

	-- Apply saved config on startup
	if config.performanceModeEnabled then
		state.petsRemoved = true
		-- Don't run the full performance mode on startup to avoid lag
		-- Just set the state and disable wind
		pcall(function()
			local windScript = game:GetService("Players").LocalPlayer.PlayerScripts.Env.Wind
			if windScript then
				windScript.Enabled = false
			end
		end)
		
		if WindUI then 
			WindUI:Notify({ 
				Title = "⚡ Performance Mode", 
				Content = "Performance Mode loaded from config (Wind disabled)", 
				Duration = 3 
			}) 
		end
	end

	-- Store references for external access
	Performance.Toggle = performanceToggle
	Performance.Activate = activatePerformanceMode
	Performance.Deactivate = deactivatePerformanceMode
	Performance.SaveConfig = saveConfig
	Performance.LoadConfig = loadConfig

	return Performance
end

return Performance


