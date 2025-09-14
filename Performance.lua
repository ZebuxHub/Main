-- Performance.lua - Pet Model Removal Toggle

local Performance = {}

-- Dependencies (injected)
local WindUI, Tabs

-- State to track if pets are removed
local state = {
	petsRemoved = false
}

-- Function to clean pet models and player built blocks (remove unwanted parts, keep essential structure)
local function removePetModels()
	if state.petsRemoved then
		if WindUI then WindUI:Notify({ Title = "🧹 Model Cleanup", Content = "Model cleanup already applied", Duration = 2 }) end
		return
	end

	local totalModelsProcessed = 0
	local totalPartsRemoved = 0

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

	state.petsRemoved = true
	
	if WindUI then 
		WindUI:Notify({ 
			Title = "🧹 Model Cleanup", 
			Content = "Cleaned " .. totalModelsProcessed .. " models, removed " .. totalPartsRemoved .. " unnecessary parts", 
			Duration = 4 
		}) 
	end
end

-- Function to disable model cleanup (note: removed parts can't be restored)
local function restorePetModels()
	if not state.petsRemoved then
		if WindUI then WindUI:Notify({ Title = "🧹 Model Cleanup", Content = "Model cleanup not applied", Duration = 2 }) end
		return
	end

	state.petsRemoved = false
	
	if WindUI then 
		WindUI:Notify({ 
			Title = "🧹 Model Cleanup", 
			Content = "Model cleanup disabled (removed parts can't be restored)", 
			Duration = 3 
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

	-- Create toggle for model cleanup
	local petRemovalToggle = Tabs.PerfTab:Toggle({
		Title = "🧹 Clean All Models",
		Desc = "Remove unnecessary parts from pets and player built blocks for better performance",
		Value = false,
		Callback = function(stateOn)
			if stateOn then 
				removePetModels() 
			else 
				restorePetModels() 
			end
		end
	})

	-- Store references for external access
	Performance.Toggle = petRemovalToggle
	Performance.RemovePets = removePetModels
	Performance.RestorePets = restorePetModels

	return Performance
end

return Performance


