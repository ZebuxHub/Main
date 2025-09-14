-- Performance.lua - Pet Model Removal Toggle

local Performance = {}

-- Dependencies (injected)
local WindUI, Tabs

-- State to track if pets are removed
local state = {
	petsRemoved = false
}

-- Function to clean pet models (remove unwanted parts, keep essential structure)
local function removePetModels()
	if state.petsRemoved then
		if WindUI then WindUI:Notify({ Title = "🐾 Pet Cleanup", Content = "Pet cleanup already applied", Duration = 2 }) end
		return
	end

	-- Find the Pets folder in workspace
	local petsFolder = workspace:FindFirstChild("Pets")
	if not petsFolder then
		if WindUI then WindUI:Notify({ Title = "🐾 Pet Cleanup", Content = "No Pets folder found", Duration = 2 }) end
		return
	end

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

	local petCount = 0
	local removedPartsCount = 0

	-- Process each pet model
	for _, petModel in pairs(petsFolder:GetChildren()) do
		if petModel:IsA("Model") then
			petCount = petCount + 1
			
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
						removedPartsCount = removedPartsCount + 1
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
							removedPartsCount = removedPartsCount + 1
						end)
					end
				end
			end
		end
	end

	state.petsRemoved = true
	
	if WindUI then 
		WindUI:Notify({ 
			Title = "🐾 Pet Cleanup", 
			Content = "Cleaned " .. petCount .. " pets, removed " .. removedPartsCount .. " unnecessary parts", 
			Duration = 4 
		}) 
	end
end

-- Function to disable pet cleanup (note: removed parts can't be restored)
local function restorePetModels()
	if not state.petsRemoved then
		if WindUI then WindUI:Notify({ Title = "🐾 Pet Cleanup", Content = "Pet cleanup not applied", Duration = 2 }) end
		return
	end

	state.petsRemoved = false
	
	if WindUI then 
		WindUI:Notify({ 
			Title = "🐾 Pet Cleanup", 
			Content = "Pet cleanup disabled (removed parts can't be restored)", 
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

	-- Create toggle for pet model cleanup
	local petRemovalToggle = Tabs.PerfTab:Toggle({
		Title = "🐾 Clean Pet Models",
		Desc = "Remove unnecessary parts from pets, keep only essential components for performance",
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


