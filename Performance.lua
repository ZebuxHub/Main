-- Performance.lua - Master performance toggle (apply/restore all reducers)

local Performance = {}

-- Services
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")

-- Dependencies (injected)
local WindUI, Tabs

-- State caches for restoration
local state = {
	applied = false,
	-- Global
	streaming = {},
	quality = nil,
	cameraFOV = nil,
	-- Lighting/Terrain
	lightingProps = {},
	postEffects = {},
	terrain = {},
	-- Visual instances
	effects = {},
	lights = {},
	decals = {},
	textures = {},
	meshTextures = {},
	specialMeshTextures = {},
	surfaceApps = {},
	billboards = {},
	surfaceGuis = {},
	parts = {}, -- [Instance] = {Material, CastShadow, Reflectance, RenderFidelity?}
	-- Animations
	animators = {}, -- [Animator] = connection
	animateScripts = {}, -- {inst, prevDisabled}
}

local function safelySet(inst, prop, value)
	pcall(function()
		inst[prop] = value
	end)
end

local function isInPlayerGui(inst)
	local lp = Players.LocalPlayer
	local pg = lp and lp:FindFirstChild("PlayerGui")
	return pg and inst:IsDescendantOf(pg)
end

local function stopAndBlockAnimator(animator)
	if not animator then return end
	local ok, tracks = pcall(function()
		return animator:GetPlayingAnimationTracks()
	end)
	if ok and tracks then
		for _, t in ipairs(tracks) do
			pcall(function()
				t:Stop(0)
			end)
		end
	end
	local ev
	local okc, res = pcall(function()
		return animator.AnimationPlayed
	end)
	if okc and res and typeof(res.Connect) == "function" then
		ev = res:Connect(function(track)
			pcall(function()
				track:Stop(0)
			end)
		end)
		state.animators[animator] = ev
	end
end

local function applyAll()
	if state.applied then
		if WindUI then WindUI:Notify({ Title = "⚡ Performance", Content = "Already ON", Duration = 2 }) end
		return
	end

	-- Save globals
	local cam = workspace.CurrentCamera
	state.cameraFOV = cam and cam.FieldOfView
	state.streaming = {
		enabled = workspace.StreamingEnabled,
		minRadius = workspace.StreamingMinRadius,
		targetRadius = workspace.StreamingTargetRadius,
	}
	pcall(function()
		state.quality = settings().Rendering.QualityLevel
	end)

	-- Save lighting props
	state.lightingProps = {
		GlobalShadows = Lighting.GlobalShadows,
		EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
		EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		Brightness = Lighting.Brightness,
		FogStart = Lighting.FogStart,
		FogEnd = Lighting.FogEnd,
		Technology = Lighting.Technology,
		ColorShift_Top = Lighting.ColorShift_Top,
		ColorShift_Bottom = Lighting.ColorShift_Bottom,
	}

	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		state.terrain = {
			Decoration = terrain.Decoration,
			WaterWaveSize = terrain.WaterWaveSize,
			WaterWaveSpeed = terrain.WaterWaveSpeed,
			WaterTransparency = terrain.WaterTransparency,
			WaterReflectance = terrain.WaterReflectance,
		}
	end

	-- Apply Lighting reductions
	safelySet(Lighting, "GlobalShadows", false)
	safelySet(Lighting, "EnvironmentDiffuseScale", 0)
	safelySet(Lighting, "EnvironmentSpecularScale", 0)
	safelySet(Lighting, "Technology", Enum.Technology.Compatibility)
	safelySet(Lighting, "Ambient", Color3.fromRGB(128,128,128))
	safelySet(Lighting, "OutdoorAmbient", Color3.fromRGB(128,128,128))
	safelySet(Lighting, "Brightness", 1)
	safelySet(Lighting, "ColorShift_Top", Color3.fromRGB(0,0,0))
	safelySet(Lighting, "ColorShift_Bottom", Color3.fromRGB(0,0,0))
	safelySet(Lighting, "FogStart", 0)
	safelySet(Lighting, "FogEnd", 100)
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("PostEffect") then
			state.postEffects[child] = child.Enabled
			safelySet(child, "Enabled", false)
		elseif child:IsA("Atmosphere") then
			state.postEffects[child] = child.Density
			safelySet(child, "Density", 0)
		end
	end

	-- Terrain reductions
	if terrain then
		safelySet(terrain, "Decoration", false)
		safelySet(terrain, "WaterWaveSize", 0)
		safelySet(terrain, "WaterWaveSpeed", 0)
		safelySet(terrain, "WaterTransparency", 1)
		safelySet(terrain, "WaterReflectance", 0)
	end

	-- Streaming/Quality/Camera
	pcall(function()
		workspace.StreamingEnabled = true
		workspace.StreamingMinRadius = 32
		workspace.StreamingTargetRadius = 64
	end)
	pcall(function()
		settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
	end)
	if cam then
		safelySet(cam, "FieldOfView", math.clamp((state.cameraFOV or 70) - 10, 40, 120))
	end

	-- World reductions
	for _, inst in ipairs(game:GetDescendants()) do
		if not isInPlayerGui(inst) then
			if inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam") or inst:IsA("Smoke") or inst:IsA("Fire") or inst:IsA("Sparkles") or inst:IsA("Highlight") then
				state.effects[inst] = inst.Enabled
				safelySet(inst, "Enabled", false)
			elseif inst:IsA("PointLight") or inst:IsA("SpotLight") or inst:IsA("SurfaceLight") then
				state.lights[inst] = inst.Enabled
				safelySet(inst, "Enabled", false)
			elseif inst:IsA("Decal") then
				table.insert(state.decals, {inst = inst, texture = inst.Texture, transparency = inst.Transparency})
				pcall(function() inst.Texture = "" end)
				safelySet(inst, "Transparency", 1)
			elseif inst:IsA("Texture") then
				table.insert(state.textures, {inst = inst, texture = inst.Texture, transparency = inst.Transparency})
				pcall(function() inst.Texture = "" end)
				safelySet(inst, "Transparency", 1)
			elseif inst:IsA("MeshPart") then
				local partData = { Material = inst.Material, CastShadow = inst.CastShadow, Reflectance = inst.Reflectance }
				local prev
				pcall(function()
					prev = inst.RenderFidelity
					inst.RenderFidelity = Enum.RenderFidelity.Performance
				end)
				if prev ~= nil then partData.RenderFidelity = prev end
				pcall(function()
					if inst.TextureID ~= nil then
						table.insert(state.meshTextures, {inst = inst, textureId = inst.TextureID})
						inst.TextureID = ""
					end
				end)
				state.parts[inst] = partData
				safelySet(inst, "Material", Enum.Material.Plastic)
				safelySet(inst, "CastShadow", false)
				safelySet(inst, "Reflectance", 0)
			elseif inst:IsA("SpecialMesh") then
				local prev
				pcall(function() prev = inst.TextureId; inst.TextureId = "" end)
				if prev ~= nil then table.insert(state.specialMeshTextures, {inst = inst, textureId = prev}) end
			elseif inst:IsA("SurfaceAppearance") then
				table.insert(state.surfaceApps, {inst = inst, parent = inst.Parent})
				pcall(function() inst.Parent = nil end)
			elseif inst:IsA("BillboardGui") then
				state.billboards[inst] = inst.Enabled
				safelySet(inst, "Enabled", false)
			elseif inst:IsA("SurfaceGui") then
				state.surfaceGuis[inst] = inst.Enabled
				safelySet(inst, "Enabled", false)
			elseif inst:IsA("BasePart") then
				local partData = { Material = inst.Material, CastShadow = inst.CastShadow, Reflectance = inst.Reflectance }
				state.parts[inst] = partData
				safelySet(inst, "Material", Enum.Material.Plastic)
				safelySet(inst, "CastShadow", false)
				safelySet(inst, "Reflectance", 0)
			end
		end

		-- Kill animations
		if inst:IsA("Animator") then
			stopAndBlockAnimator(inst)
		elseif (inst:IsA("LocalScript") or inst:IsA("Script")) and inst.Name == "Animate" then
			table.insert(state.animateScripts, {inst = inst, prev = inst.Disabled})
			pcall(function() inst.Disabled = true end)
		end
	end

	state.applied = true
	if WindUI then WindUI:Notify({ Title = "⚡ Performance", Content = "Ultra Performance ON", Duration = 3 }) end
end

local function restoreAll()
	if not state.applied then
		if WindUI then WindUI:Notify({ Title = "⚡ Performance", Content = "Already OFF", Duration = 2 }) end
		return
	end

	-- Restore lighting/post effects
	for k, v in pairs(state.lightingProps) do
		pcall(function() Lighting[k] = v end)
	end
	for inst, prev in pairs(state.postEffects) do
		if inst and inst.Parent then
			pcall(function()
				if inst:IsA("Atmosphere") then inst.Density = tonumber(prev) or 0 else inst.Enabled = prev and true or false end
			end)
		end
	end
	state.postEffects = {}

	-- Restore terrain
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		for k, v in pairs(state.terrain) do
			pcall(function() terrain[k] = v end)
		end
	end

	-- Restore streaming/quality/camera
	pcall(function()
		if state.streaming.enabled ~= nil then workspace.StreamingEnabled = state.streaming.enabled end
		if state.streaming.minRadius ~= nil then workspace.StreamingMinRadius = state.streaming.minRadius end
		if state.streaming.targetRadius ~= nil then workspace.StreamingTargetRadius = state.streaming.targetRadius end
	end)
	pcall(function()
		if state.quality ~= nil then settings().Rendering.QualityLevel = state.quality end
	end)
	local cam = workspace.CurrentCamera
	if cam and state.cameraFOV ~= nil then safelySet(cam, "FieldOfView", state.cameraFOV) end

	-- Restore instances
	for inst, prev in pairs(state.effects) do if inst and inst.Parent then pcall(function() inst.Enabled = prev and true or false end) end end
	state.effects = {}
	for inst, prev in pairs(state.lights) do if inst and inst.Parent then pcall(function() inst.Enabled = prev and true or false end) end end
	state.lights = {}
	for _, rec in ipairs(state.decals) do if rec.inst and rec.inst.Parent then pcall(function() rec.inst.Texture = rec.texture or rec.inst.Texture; rec.inst.Transparency = rec.transparency or 0 end) end end
	state.decals = {}
	for _, rec in ipairs(state.textures) do if rec.inst and rec.inst.Parent then pcall(function() rec.inst.Texture = rec.texture or rec.inst.Texture; rec.inst.Transparency = rec.transparency or 0 end) end end
	state.textures = {}
	for _, rec in ipairs(state.meshTextures) do if rec.inst and rec.inst.Parent then pcall(function() rec.inst.TextureID = rec.textureId or "" end) end end
	state.meshTextures = {}
	for _, rec in ipairs(state.specialMeshTextures) do if rec.inst and rec.inst.Parent then pcall(function() rec.inst.TextureId = rec.textureId or "" end) end end
	state.specialMeshTextures = {}
	for _, rec in ipairs(state.surfaceApps) do if rec.inst and rec.parent and rec.parent.Parent then pcall(function() rec.inst.Parent = rec.parent end) end end
	state.surfaceApps = {}
	for inst, prev in pairs(state.billboards) do if inst and inst.Parent then pcall(function() inst.Enabled = prev and true or false end) end end
	state.billboards = {}
	for inst, prev in pairs(state.surfaceGuis) do if inst and inst.Parent then pcall(function() inst.Enabled = prev and true or false end) end end
	state.surfaceGuis = {}
	for inst, data in pairs(state.parts) do if inst and inst.Parent then pcall(function()
		inst.Material = data.Material; inst.CastShadow = data.CastShadow; inst.Reflectance = data.Reflectance; if data.RenderFidelity ~= nil and inst:IsA("MeshPart") then inst.RenderFidelity = data.RenderFidelity end
	end) end end
	state.parts = {}

	-- Restore animations
	for animator, conn in pairs(state.animators) do if conn then pcall(function() conn:Disconnect() end) end end
	state.animators = {}
	for _, rec in ipairs(state.animateScripts) do if rec.inst and rec.inst.Parent then pcall(function() rec.inst.Disabled = rec.prev and true or false end) end end
	state.animateScripts = {}

	state.applied = false
	if WindUI then WindUI:Notify({ Title = "⚡ Performance", Content = "Ultra Performance OFF", Duration = 3 }) end
end

function Performance.Init(deps)
	WindUI = deps.WindUI
	Tabs = deps.Tabs

	-- Ensure Performance tab exists
	if not Tabs.PerfTab then
		Tabs.PerfTab = Tabs.MainSection:Tab({ Title = "🚀 | Performance" })
	end

	local masterToggle = Tabs.PerfTab:Toggle({
		Title = "⚡ Ultra Performance Mode",
		Desc = "One toggle: disable animations, effects, lighting, textures, materials, lights",
		Value = false,
		Callback = function(stateOn)
			if stateOn then applyAll() else restoreAll() end
		end
	})

	Performance.Toggle = masterToggle
	Performance.Apply = applyAll
	Performance.Restore = restoreAll

	return Performance
end

return Performance


