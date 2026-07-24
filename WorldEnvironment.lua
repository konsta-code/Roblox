-- WorldEnvironment.lua
-- Ablageort: ServerScriptService (ModuleScript, von MapDirector benutzt)
--
-- Setzt Licht / Atmosphaere / Wolken passend zum gewaehlten Theme. Aus dem
-- frueheren Standalone-Script WorldEnvironment.server.lua geworden, jetzt
-- deterministisch von MapDirector NACH dem Terrain aufgerufen (kein Attribut-
-- Timing mehr). Erwartet ein env-Table wie in MapPoolConstants.Themes[x].env.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")

local WorldEnvironment = {}

local EFFECT_NAMES = { "TribesAtmosphere", "TribesBloom", "TribesGrade", "TribesSunRays", "TribesDepth" }

function WorldEnvironment.apply(env)
	Lighting.ClockTime = env.clockTime
	Lighting.Brightness = env.brightness
	Lighting.Ambient = env.ambient
	Lighting.OutdoorAmbient = env.outdoorAmbient
	Lighting.ColorShift_Top = env.colorTop
	Lighting.ColorShift_Bottom = env.colorBottom
	Lighting.EnvironmentDiffuseScale = 0.85
	Lighting.EnvironmentSpecularScale = 0.7
	Lighting.ExposureCompensation = 0.12
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.55
	Lighting.GeographicLatitude = env.geoLatitude
	Lighting.FogColor = env.fog.color
	Lighting.FogStart = env.fog.start
	Lighting.FogEnd = env.fog.finish

	for _, name in EFFECT_NAMES do
		local prev = Lighting:FindFirstChild(name)
		if prev then
			prev:Destroy()
		end
	end

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "TribesAtmosphere"
	atmosphere.Density = env.atmosphere.density
	atmosphere.Offset = env.atmosphere.offset
	atmosphere.Color = env.atmosphere.color
	atmosphere.Decay = env.atmosphere.decay
	atmosphere.Glare = env.atmosphere.glare
	atmosphere.Haze = env.atmosphere.haze
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Name = "TribesBloom"
	bloom.Intensity = env.bloom.intensity
	bloom.Size = env.bloom.size
	bloom.Threshold = env.bloom.threshold
	bloom.Parent = Lighting

	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "TribesGrade"
	grade.Brightness = env.grade.brightness
	grade.Contrast = env.grade.contrast
	grade.Saturation = env.grade.saturation
	grade.TintColor = env.grade.tint
	grade.Parent = Lighting

	local sunRays = Instance.new("SunRaysEffect")
	sunRays.Name = "TribesSunRays"
	sunRays.Intensity = env.sunRays.intensity
	sunRays.Spread = env.sunRays.spread
	sunRays.Parent = Lighting

	-- Keine Fern-Unschaerfe mehr: sonst verschwimmt die Weitsicht. Nur ganz
	-- dezenter Nah-Effekt bleibt aus (0), damit die Landschaft scharf bis zum
	-- Horizont steht.
	local depth = Instance.new("DepthOfFieldEffect")
	depth.Name = "TribesDepth"
	depth.FarIntensity = 0
	depth.FocusDistance = 900
	depth.InFocusRadius = 900
	depth.NearIntensity = 0
	depth.Parent = Lighting

	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		local prevClouds = terrain:FindFirstChild("TribesClouds")
		if prevClouds then
			prevClouds:Destroy()
		end
		local clouds = Instance.new("Clouds")
		clouds.Name = "TribesClouds"
		clouds.Cover = env.clouds.cover
		clouds.Density = env.clouds.density
		clouds.Color = env.clouds.color
		clouds.Parent = terrain
	end

	SoundService.AmbientReverb = Enum.ReverbType.Plain
	SoundService.DistanceFactor = 3.33
	SoundService.DopplerScale = 1.15
end

return WorldEnvironment
