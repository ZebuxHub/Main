-- Performance.lua - Pet Model Removal Toggle

local Performance = {}

-- Dependencies (injected)
local WindUI, Tabs

-- State to track if pets are removed
local state = {
	petsRemoved = false
}

-- Function to remove all pet models from workspace.Pets
local function removePetModels()
	if state.petsRemoved then
		if WindUI then WindUI:Notify({ Title = "🐾 Pet Removal", Content = "Pets already removed", Duration = 2 }) end
		return
	end

	-- Find the Pets folder in workspace
	local petsFolder = workspace:FindFirstChild("Pets")
	if not petsFolder then
		if WindUI then WindUI:Notify({ Title = "🐾 Pet Removal", Content = "No Pets folder found", Duration = 2 }) end
		return
	end

	-- Count pets before removal
	local petCount = 0
	for _, petModel in pairs(petsFolder:GetChildren()) do
		if petModel:IsA("Model") then
			petCount = petCount + 1
		end
	end

	-- Remove all pet models
	for _, petModel in pairs(petsFolder:GetChildren()) do
		if petModel:IsA("Model") then
			pcall(function()
				petModel:Destroy()
			end)
		end
	end

	state.petsRemoved = true
	
	if WindUI then 
		WindUI:Notify({ 
			Title = "🐾 Pet Removal", 
			Content = "Removed " .. petCount .. " pet models for performance", 
			Duration = 3 
		}) 
	end
end

-- Function to restore pets (note: this won't actually restore them since they're destroyed)
local function restorePetModels()
	if not state.petsRemoved then
		if WindUI then WindUI:Notify({ Title = "🐾 Pet Removal", Content = "Pets not removed", Duration = 2 }) end
		return
	end

	state.petsRemoved = false
	
	if WindUI then 
		WindUI:Notify({ 
			Title = "🐾 Pet Removal", 
			Content = "Pet removal disabled (models can't be restored)", 
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

	-- Create toggle for pet model removal
	local petRemovalToggle = Tabs.PerfTab:Toggle({
		Title = "🐾 Remove Pet Models",
		Desc = "Remove all pet models from workspace.Pets folder for better performance",
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


